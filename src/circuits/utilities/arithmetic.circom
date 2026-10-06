pragma circom 2.2.1;

include "branching.circom";
include "../../../libs/node_modules/circomlib/circuits/comparators.circom";

/**
* Computes how many bits are needed to represent x.
* This is: ceil(log2(x+1))
*/
function numBits(x) {
    // Ensure input is greater than 0
    if (x <= 0) { 
        return 0; // Default value for invalid input
    }
    x += 1;

    var result = 0;
    var value = 1;

    // Increment result until 2^result >= x
    while (value < x) {
        value *= 2;
        result++;
    }

    return result;
}

/**
* Computes the inverse of an element. Caution, only works if in is invertible.
*/
template invert() {
    signal input in;

    signal output out;

    signal inv <-- 1/in;

    1 === inv*in;
    out <== inv;
}

/**
* Computes numerator/denominator if the denominator is not zero. Caution, only works if denominator is not 0.
*/
template division() {
    signal input numerator;
    signal input denominator;

    signal res;

    signal output out;

    res <-- numerator/denominator;
    numerator === res * denominator;

    out <== res;
}

/**
* Computes numerator/denominator if the denominator is nonzero. Otherwise, computes numerator/1=numerator;
*/
template divisionSafe() {
    signal input numerator;
    signal input denominator;

    signal res;

    signal output out;

    component isZero = IsZero();
    isZero.in <== denominator;

    signal fixedDenominator <== denominator + isZero.out;

    res <-- numerator/fixedDenominator;
    numerator === res * fixedDenominator;

    out <== res;
}
