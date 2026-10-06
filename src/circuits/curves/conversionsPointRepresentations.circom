pragma circom 2.2.1;

include "../utilities/branching.circom";
include "../utilities/arithmetic.circom";
include "affinePoint.circom";
include "projectivePoint.circom";
include "../../../libs/node_modules/circomlib/circuits/comparators.circom";

template affineToProjective() {
    input AffinePoint() in;

    output ProjectivePoint() out;

    component ifThenElse = ifThenElseMulti(3);

    ifThenElse.ifV[0] <== in.x;
    ifThenElse.ifV[1] <== in.y;
    ifThenElse.ifV[2] <== 1;

    ifThenElse.elseV[0] <== 0;
    ifThenElse.elseV[1] <== 1;
    ifThenElse.elseV[2] <== 0;

    ifThenElse.cond <== in.notInfty;

    out.X <== ifThenElse.out[0];
    out.Y <== ifThenElse.out[1];
    out.Z <== ifThenElse.out[2]; 
}

template projectiveToAffine() {
    input ProjectivePoint() in;

    output AffinePoint() out;

    component zZero = IsZero();
    zZero.in <== in.Z;

    signal changedZ <== zZero.out + in.Z; // Is 1, if Z is zero and Z otherwise.

    component xDivZ = division();
    component yDivZ = division();
    xDivZ.numerator <== in.X;
    xDivZ.denominator <== changedZ;
    yDivZ.numerator <== in.Y;
    yDivZ.denominator <== changedZ;

    out.x <== xDivZ.out;
    out.y <== yDivZ.out;
    out.notInfty <== 1 - zZero.out; // If Z is zero, the point is the point at infinity.

    // Test:
    // input AffinePoint() test;
    // test === out;
}
