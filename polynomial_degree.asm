; Rozwiązanie 1 zadania zaliczeniowego. Autor: Agata Załęska
; W rozwiązaniu korzystam z wskazówki do zadania. Powtarzam wielokrotnie zastąpienie
; liczb w tablicy różnicą sąsiednich liczb (ilość liczb maleje z każdym krokiem)
; w pętli, aż wszystkie będą równe (lub zostanie 1 liczba). Ilość wykonanych kroków, to wynik - stopień wielomianu.
; Oprócz tego przy odejmowaniu, liczby mogą znacznie przekroczyć zakres inta, zatem korzystam
; z arytmetyki dużych liczb.

; Przeznaczenie rejestrów:
; r8 i r9 - będą służyć głównie jako wskaźniki do poruszania się po dużych liczbach
; r10 - rejestr pomocniczy
; r11 - ilość bajtów potrzebna do przechowania dużej liczby
; rbx - ilośc liczb w tablicy (zmniejsza się po pętli z odejmowaniem)
; rejestrów rcx i rdx będę używać do organizacji pętli

global polynomial_degree

section .rodata

INT_SIZE equ 4 ; stała na rozmiar inta w bajtach
MASK_ONES_3_ZEROS equ 0xfffffffffffffff8 ; maska bitowa - same jedynki i 3 zera na końcu
MASK_ZEROS equ 0 ; maska bitowa - same zera
MASK_ONES equ 0xff ; maska bitowa - same jedynki

section .text

polynomial_degree:
        ; umieszczam na stosie rbx aby pod koniec programu przywrócić poprzednią wartość
        push    rbx ; w rbx będziemy trzymać ilość pozostałych liczb

        ; najpierw sprawdzimy, czy wszystkie liczby w tablicy są zerowe
        mov     rcx, rsi ; rcx posłuży nam do organizacji pętli - powinna się wykonać n razy
        mov     r8, rdi ; zapisujemy wskaźnik na tablicę, żeby nie stracić oryginalnej wartości

.check_all_zero:
        cmp     dword [r8], 0 ; po kolei porównujemy wszystkie elementy z zerem
        jnz     .not_all_zero ; jesli są różne, przechodzimy do kolejnej cześci programu

        add     r8, INT_SIZE ; przechodzimy do następnego elementu tablicy
        loop    .check_all_zero
        jmp     .all_zero ; jeśli nie wykonamy powyższego skoku, wiemy że wszystkie liczby są zerem

.not_all_zero:
        ; do przechowywania jednej dużej liczby potrzeba 32 + n bitów = 5 + n/8 bajtów,
        ; ponieważ początkowo potrzebujemy 32 bity - ta liczba może się zwiększyć
        ; po wykonaniu operacji sub (maksymalnie może urosnąć n razy)
        ; potem zaokrągle w górę do wielokrotności 8 dodając jeszcze 7 i zerując 3 ostatnie bity
        mov     r11, rsi ; w r11 będzie potrzebna ilość bajtów do przechowania dużej liczby
        shr     r11, 3 ; przsuwamy bity w prawo o 3, czyli dzielimy całkowicie przez 8
        add     r11, 12 ; 12 = 5 + 7 (wytłumaczone powyżej)
        and     r11, MASK_ONES_3_ZEROS ; logiczny and zeruje ostatnie 3 bity - zaokrąglamy do wielokr. 8

        mov     rbx, rsi ; w rbx ile zostało liczb w tablicy do porównywania
        mov     rcx, rsi ; do rcxa wpisujemy ilość potrzebnych obrotów pętli

.allocate_loop: ; alokacja potrzebnej pamięci - alokujemy n * r11 bajtów
        sub     rsp, r11
        loop    .allocate_loop

.fill_big_nums: ; przepisujemy tablicę na duże liczby, które właśnie zaalokowaliśmy
        mov     r8, rsp ; w r8 zapisujemy wartość wskazującą na pierwszą liczbę
        xor     rdx, rdx ; licznik ile wypełniliśmy dużych liczb

.fill_another:
        mov     r10d, [rdi] ; w r10 będziemy przechowywać aktualnie przenoszoną liczbę
        mov     [r8], r10d ; wpisujemy liczbę na wyznaczone miejsce

        add     r8, INT_SIZE ; zapełniliśmy pierwsze 4 bajty - zostało jeszcze r11 - 4
        mov     rcx, r11
        sub     rcx, INT_SIZE ; rcx - ile bajtów pozostało do wypełnienia

        test    r10d, r10d ; sprawdzamy znak liczby
        js      .fill_negative ; jeśli ujemna - dopiszemy wiodące jedynki
        jmp     .fill_positive ; wpp dopiszemy wiodące zera

.fill_negative:
        or      byte [r8], MASK_ONES ; wstawiamy same jedynki do kolejnych bitów dużej liczby
        inc     r8 ; przejście do następnego bajtu
        loop    .fill_negative
        jmp     .fill_next ; po zakończeniu idziemy wypełnić następną liczbę

.fill_positive:
        and     byte [r8], MASK_ZEROS ; wstawiamy same zera do kolejnych bitów dużej liczby
        inc     r8 ; przejście do następnego bajtu
        loop    .fill_positive

.fill_next:
        add     rdi, INT_SIZE ; przemieszczamy się do kolejnej liczby - utrata wartości rdi nie przeszkadza
        inc     rdx ; zaznaczamy, że wypełniliśmy kolejną liczbę
        cmp     rdx, rsi ; sprawdzamy czy zostały jeszcze jakieś liczby do wypełnienia
        jnz     .fill_another ; zauważmy, że jeśli wypełniamy dalej, r8 jest na początku kolejnej liczby
        jmp     .compare_all ; po wypełnieniu sprawdzamy równość wszystkich elementów

.compare_all_update_rbx:
        dec     rbx ; po zakończeniu odejmowania zmniejszamy licznik rbx

.compare_all: ; sprawdźmy wszystkie elementy z pierwszym
        xor     rdx, rdx ; licznik ile porównaliśmy par
        inc     rdx ; mamy rbx - 1 par do porównania - rdx zaczyna od 1
        mov     r8, rsp ; w r8 będziemy trzymać wskaźniki na kolejne elementy tablicy
        add     r8, r11 ; r8 teraz wskazuje na drugi element tablicy - będziemy porównywać go z pierwszym

.compare_all_loop:
        cmp     rdx, rbx ; porównujemy licznik porównanych par z rbx -> ilość elementów
        jz      .all_equal ; nie ma nic do porównania

        mov     r9, rsp ; ustawiamy r9, żeby wskazywało na pierwszy element
        mov     rcx, r11 ; rcx - ile par bajtów musimy ze sobą porównać

.compare_two: ; porównujemy r11 bajtów bajt po bajcie
        mov     r10b, [r9] ; przenosimy bajt pierwszego elementu do r11b
        cmp     r10b, [r8]
        jnz     .subtract_all ; jeśli znaleźliśmy jakąkolwiek nierówność - idziemy do odejmowania

        inc     r9 ; kolejny bajt pierwszej liczby
        inc     r8 ; kolejny bajt porównywanej z pierwszą liczby
        loop    .compare_two

.two_equal:
        inc     rdx ; porównaliśmy kolejną parę - zwiększamy rdx
        jmp     .compare_all_loop ; porównujemy dalej

.all_equal: ; wszystke liczby są równe - kończymy działanie programu
        mov     rax, rsi ; wynik to będzie n - ilość pozostałych liczb
        sub     rax, rbx ; równoważnie jest to ilość wykonanych kroków
        jmp     .free_and_exit ; idziemy zwolnić pamięć i zakończyć funkcję

.subtract_all: ; odejmujemy od siebie sąsiednie pary dużych liczb
        mov     r8, rsp ; r8 będzie naszym odjemną
        mov     r9, rsp
        add     r9, r11 ; r9 to będzie odjemnikiem - sąsiednia liczba
        xor     rdx, rdx ; licznik ile par już odjęliśmy

.subtracting_loop:
        inc     rdx ; przed odejmowaniem zwiększamy licznik (mamy docelowo rbx - 1 par)
        cmp     rdx, rbx ; sprawdzenie, czy zakończyliśmy odejmowanie dla wszystkich par
        jz      .compare_all_update_rbx ; jeśli tak, znowu porównujemy

        mov     rcx, r11 ; porównując 2 liczby, musimy obsłużyć r11 bajtów
        add     rcx, 0 ; ponieważ korzystamy z sbb, upewniamy się, że CF nie będzie ustawione

.subtract_two: ; odejmujemy od siebie 2 sąsiednie liczby
        mov     r10b, [r9]
        sbb     byte [r8], r10b ; korzystamy z sbb, aby uwzględniać przeniesienie z młodszych bitów
        inc     r8 ; przejście do kolejnego bajtu
        inc     r9 ; przejście do kolejnego bajtu
        loop    .subtract_two
        jmp     .subtracting_loop ; skaczemy do odejmowania następnej pary

.free_and_exit:
        mov     rcx, rsi ; licznik do pętli ze zwalnianiem pamięci

.free_loop: ; zwalnianie pamięci - zwalniamy n * r11 bajtów
        add     rsp, r11
        loop    .free_loop
        jmp     .exit

.all_zero:
        mov     rax, -1 ; zwracamy -1 w przypadku wielomianu zerowego

.exit:
        pop     rbx ; przywracamy oryginalną wartość rbx
        ret