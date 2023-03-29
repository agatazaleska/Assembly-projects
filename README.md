# Assembly projects

These are project tasks for "Operating Systems" course at University of Warsaw, the Faculty of Mathematics, Informatics and Mechanics, 2021/2022. I do not own the idea for these projects.

## Processor emulator

The program emulates SO processor with four 8-bit registers, an 8-bit instruction counter and single bits flags:
carry/borrow flag and zero flag.

The addresses in the SO processor are 8-bit. The address spaces for data and program are separate. 
The data memory contains 256 bytes, the program memory contains 256 16-bit words.
All operations on data and addresses are performed modulo 256. 

## Polynomial degree

A function calculating the degree of a given polynomial.
Signature: int polynomial_degree(int const *y, size_t n);
Where y is a pointer to an array of integers, n is the lenghts of this array.

Output: the smallest degree of a polynomial w(x), such that w(x+kr)=yk for some real number x, 
some non-zero real number r, and k=0,1,2,...,n-1.
