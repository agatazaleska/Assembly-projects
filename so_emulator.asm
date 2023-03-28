global so_emul

; w sekcji rodata przechowuję tablice adresów do danych labeli, aby uniknąć
; porównywania kodu instrukcji z każdą możliwą wartością po kolei
; nieużywane wartości zastąpiłam zerami
section .rodata
ins_type_table dq so_emul.two_argument_ins - ins_type_table, \
                  so_emul.one_argument_ins - ins_type_table, \
                  so_emul.zero_argument_ins - ins_type_table, \
                  so_emul.jump_ins - ins_type_table

two_arg_ins_table dq so_emul.MOV - two_arg_ins_table, 0, so_emul.OR - two_arg_ins_table, 0, \
                     so_emul.ADD - two_arg_ins_table, so_emul.SUB - two_arg_ins_table, \
                     so_emul.ADC - two_arg_ins_table, so_emul.SBB - two_arg_ins_table, \
                     so_emul.XCHG - two_arg_ins_table

; MOVI i ADDI nie mają własnego labela, bo wykonują ten samo kod co MOV i ADD
one_arg_ins_table dq so_emul.MOV - one_arg_ins_table, 0, 0, so_emul.XORI - one_arg_ins_table, \
                     so_emul.ADD - one_arg_ins_table, so_emul.CMPI - one_arg_ins_table, \
                     so_emul.RCR - one_arg_ins_table

jump_ins_table dq so_emul.JMP - jump_ins_table, 0, so_emul.JNC - jump_ins_table, \
                  so_emul.JC - jump_ins_table, so_emul.JNZ - jump_ins_table, \
                  so_emul.JZ - jump_ins_table, 0,  so_emul.exit - jump_ins_table

; w sekcji bss przechowuję tablicę stanów procesora o rozmiarze CORES
; każdy wątek ma swój stan procesora
section .bss
processor_states_arr resq CORES
xchg_lock resd 1 ; 'semafor' na potrzeby instrukcji xchg

section .text

; funkcja pomocnicza - zwraca adres szukanego argumentu w raxie
decode_arg_ptr:
        cmp     r12, 4
        jl      .get_register ; szukany argument jest rejestrem

        cmp     r12, 6
        jl      .get_arg_4_5
        jmp     .get_arg_6_7

.get_register:
        lea     rax, [r10 + r12] ; zwracamy wskaźnik na odpowiedni rejestr
        ret

.get_arg_4_5: ; zawracamy wskaźnik na [X] lub [Y], czyli rsi + X/Y
        movzx   rax, byte [r10 + r12 - 2] ; interesuje nas konkretna wartość X
        lea     rax, [rax + rsi] ; dodajemy do wyniku wartość wskaźnika na data
        ret

.get_arg_6_7: ; [X + D] lub [Y + D] - chcemy X/Y + D - rax + 2/3 -> (dil - 4)
        mov     r9b, byte [r10 + r12 - 4]
        add     r9b, byte [r10 + 1] ; dodajemy wartość rejestru D modulo 255
        movzx   rax, r9b ; wynik umieszczamy w raxie
        lea     rax, [rsi + rax]
        ret

; funkcja pomocnicza - odczytuje kod pierwszego argumentu (dla 2 i 1 argumentowych instrukcji)
; oraz dekoduje go - umieszcza wskaźnik na szukany element w r8
decode_first_argument:
        movzx   r12, r11w ; w r12 odkodujemy pierwszy argument
        shr     r12, 8
        and     r12, 0x07 ; maska bitowa - potrzebne 3 ostatnie bity
        call    decode_arg_ptr
        mov     r8, rax ; r8 - pierwszy argument
        ret

so_emul:
        push     r12 ; zachowujemy na stosie pierwotną wartość r12
        push     r13 ; oraz r13

        lea      r10, [rel processor_states_arr] ; do r10 wpisujemy adres stanu procesora
        lea      r10, [r10 + 8 * rcx] ; o numerze core

        cmp      rdx, 0 ; sprawdzamy czy wykonać jakakolwiek instrukcje
        jz       .exit ; jeśli nie, kończymy program
        mov      rcx, rdx ; rcx - ile razy ma się wykonać pętla

.next_instruction: ; najpierw odszyfrowujemy typ instrukcji
        movzx    r8, byte [r10 + 4] ; ładujemy licznik do r8
        add      byte [r10 + 4], 1 ; od razu zwiększamy licznik
        mov      r11w, [rdi + r8 * 2] ; r11w - kod instrukcji do wykonania

        movzx    r13, r11w ; w r13 wydzielamy typ instrukcji
        shr      r13, 14 ; typ instrukcji to najstarsze 2 bity - dzielimy całkowicie przez 2^14
        lea      r12, [rel ins_type_table]

; skaczemy do tablicy o adresie r12 na index r13
.jump_using_table:
        mov      r13, [r12 + 8 * r13] ; adresy są 8 bajtowe
        add      r13, r12 ; dodajemy adres tablicy
        jmp      r13

.check_if_continue: ; sprawdzenie czy kontynuujemy pętlę
        loop    .next_instruction
        jmp     .exit

; odkodowujemy instrukcję dwuargumentową
.two_argument_ins:
        call    decode_first_argument ; funkcja zapisuje pierwszy argument w r8

        movzx   r12, r11w ; odkodowujemy w r12 drugi argument
        shr     r12, 11
        call    decode_arg_ptr

        movzx   r13, r11b ; do r13 zapisujemy numer instrukcji
        mov     r11, rax ; w r11 będzie adres drugiego argumentu - do instrukcji xchg
        mov     r9b, byte [r11] ; w r9b wartość do operacji innych niż xchg

        lea     r12, [rel two_arg_ins_table]
        jmp     .jump_using_table ; wywołujemy skok do danej instrukcji

; odkodowujemy instrukcję jednoargumentową (drugi argument to stała)
.one_argument_ins:
        call decode_first_argument ; pierwszy argument odczytujemy w ten sam sposób co powyżej

        mov     r9b, r11b ; stałą 8 bitową przepisujemy z r11b, aby ujednolicić kod
        movzx   r13, r11w ; w r13 będzie numer instrukcji
        shr     r13, 11
        and     r13, 0x07 ; maska bitowa na 3 ostatnie bity

        lea     r12, [rel one_arg_ins_table]
        jmp     .jump_using_table

; odkodowujemy instrukcję bezargumentową
.zero_argument_ins:
        cmp     r11w, 0x8000 ; instrukcja to clc
        jnz     .not_clc
        and     byte [r10 + 6], 0

.not_clc:
        cmp     r11w, 0x8100 ; instrukcja to stc stc
        jnz     .not_stc
        or      byte [r10 + 6], 1

.not_stc:
        jmp     .check_if_continue ; ignorujemy/idziemy dalej po wykonaniu instrukcji

; odkodowujemy instrukcję skoku
.jump_ins:
        movzx   r13, r11w ; r13 - numer instrukcji
        shr     r13, 8
        and     r13, 0x07

        lea     r12, [rel jump_ins_table]
        jmp     .jump_using_table

.jump_r11b: ; skok o r11b
        add     byte [r10 + 4], r11b ; po prostu zwiększamy licznik pc
        jmp     .check_if_continue

; etykiety ustawiające flagi Z i C oraz przechodzące do kolejnej instrukcji
; lub końca programu
.set_z_flag:
        setz     byte [r10 + 7]
        jmp      .check_if_continue

.set_c_flag:
        setc     byte [r10 + 6]
        jmp      .check_if_continue

.set_z_and_c_flags:
        setz     byte [r10 + 7]
        setc     byte [r10 + 6]
        jmp      .check_if_continue

; etykiety wykonujące instrukcje procesora
.MOV:
        mov     byte [r8], r9b
        jmp     .check_if_continue

.OR:
        or      byte [r8], r9b
        jmp     .set_z_flag

.ADD:
        add     byte [r8], r9b
        jmp     .set_z_flag

.SUB:
        sub     byte [r8], r9b
        jmp     .set_z_flag

.ADC:
        ; ustawiamy carry na takie, jak w stanie procesora
        ; robiy to dodając do naszego C 255 - flaga i tak zostanie ponownie ustawiona
        add     byte [r10 + 6], 255
        adc     byte [r8], r9b
        jmp     .set_z_and_c_flags

.SBB:
        add     byte [r10 + 6], 255 ; analogicznie jak w ADC
        sbb     byte [r8], r9b
        jmp     .set_z_and_c_flags

.XORI:
        xor     byte [r8], r9b
        jmp     .set_z_flag

.CMPI:
        cmp     byte [r8], r9b
        jmp     .set_z_and_c_flags

.RCR:
        add     byte [r10 + 6], 255 ; analogicznie jak w ADC
        rcr     byte [r8], 1
        jmp     .set_c_flag

.CLC:
        and     byte [r10 + 6], 0 ; zerujemy C
        jmp     .check_if_continue

.STC:
        or      byte [r10 + 6], 1 ; ustawiamy C
        jmp     .check_if_continue

.JMP:
        jmp     .jump_r11b

.JNC:
        cmp     byte [r10 + 6], 1 ; sprawdzamy C
        jz      .check_if_continue ; nie wykonujemy skoku
        jmp     .jump_r11b

.JC:
        cmp     byte [r10 + 6], 0 ; sprawdzamy C
        jz      .check_if_continue
        jmp     .jump_r11b

.JNZ:
        cmp     byte [r10 + 7], 1 ; sprawdzamy Z
        jz      .check_if_continue
        jmp     .jump_r11b

.JZ:
        cmp     byte [r10 + 7], 0 ; sprawdzamy Z
        jz      .check_if_continue
        jmp     .jump_r11b

; ponieważ chcemy zamienić argumenty wskazujące na pamięć (r11b i r8b)
; musimy wykonać XCHG w 3 krokach - otaczamy je blokadą wirującą z laba
.XCHG:
        mov     r13d, 1

.loop:
lock    xchg    dword [rel xchg_lock], r13d ; atomowe sprawdzanie stanu blokady
        cmp     r13d, 0
        jne     .loop ; jeśli zajęta - sprawdzamy dalej

        mov     r12b, [r11]
        xchg    byte [r8], r12b
        xchg    byte [r11], r12b

        mov     dword [rel xchg_lock], 0 ; zwalniamy blokadę
        jmp     .check_if_continue

; przywrócenie pierwotnych wartości r12 i r13 oraz przepisanie do raxa wyniku
.exit:
        pop     r13
        pop     r12
        mov     rax, qword [r10]
        ret
