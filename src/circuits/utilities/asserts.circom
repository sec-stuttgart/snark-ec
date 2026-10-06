pragma circom 2.2.1;

include "../../../libs/node_modules/circomlib/circuits/comparators.circom";

/**
* Forces the input to be 0 or 1
*/
template assertBit() {
    input signal in;

    0 === in * (1-in);
}

/**
* Forces the in to be less than test.
* The input should have n bits.
*/
template assertLt(n) {
    input signal in;
    input signal test;

    component lt = LessThan(n);
    lt.in[0] <== in;
    lt.in[1] <== test;

    lt.out === 1;
}

/**
* Forces the in to be less than or equal to test.
* The input should have n bits.
*/
template assertLtEq(n) {
    input signal in;
    input signal test;

    component ltEq = LessEqThan(n);
    ltEq.in[0] <== in;
    ltEq.in[1] <== test;

    ltEq.out === 1;
}

/**
* Forces the in to be greater than test.
* The input should have n bits.
*/
template assertGt(n) {
    input signal in;
    input signal test;

    component gt = GreaterThan(n);
    gt.in[0] <== in;
    gt.in[1] <== test;

    gt.out === 1;
}

/**
* Forces the in to be greater than or equal to test.
* The input should have n bits.
*/
template assertGtEq(n) {
    input signal in;
    input signal test;

    component gtEq = GreaterEqThan(n);
    gtEq.in[0] <== in;
    gtEq.in[1] <== test;

    gtEq.out === 1;
}