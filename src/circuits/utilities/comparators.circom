pragma circom 2.2.1;

include "../../../libs/node_modules/circomlib/circuits/comparators.circom";

/**
* Checks whether the given signal is a bit
*/
template isBit() {
    input signal in;

    output signal out;

    component isZero = IsZero();
    isZero.in <== in * (1-in);
    out <== isZero.out;
}

