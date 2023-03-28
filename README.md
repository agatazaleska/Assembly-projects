# Assembly projects

2 programs written in assembly as university tasks

## Processor emulator

The SO processor has four 8-bit data registers named A, D, X, Y, an 8-bit instruction counter PC, 
a single-bit carry/borrow flag C for arithmetic operations, and a single-bit zero flag Z that is set when 
the result of an arithmetic-logical operation is zero and cleared otherwise. When the processor is started, 
all register and flag values are cleared to zero.

Addresses in the SO processor are 8-bit. The processor has separate address spaces for data and program. 
The data memory contains 256 bytes, and the program memory contains 256 16-bit words.

All operations on data and addresses are performed modulo 256. 
During instruction execution, the instruction counter is incremented by one and points to the next instruction to be executed, 
unless the instruction performs a jump, in which case the constant value specified in the instruction code is added to the instruction counter value. 
All jumps are relative jumps.

## Polynomial degree

Implement in assembly language a function called polynomial_degree that is called from C language with the following signature:

int polynomial_degree(int const *y, size_t n);
The arguments of the function are a pointer y to an array of integer numbers y0, y1, y2, ..., yn-1, 
and n containing the length of this array. The result of the function is the smallest degree of 
a single-variable polynomial w(x) with real coefficients, such that w(x+kr)=yk for some real number x, 
some non-zero real number r, and k=0,1,2,...,n-1.

We assume that a zero polynomial has a degree of -1. It is allowed to assume that the pointer y 
is valid and points to an array containing n elements, where n is a positive value.

Note that if a polynomial w(x) has a degree of d and d>=0, then for r ≠ 0, the polynomial w(x+r)-w(x) has a degree of d-1.
