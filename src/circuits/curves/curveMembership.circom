pragma circom 2.2.1;

include "../utilities/branching.circom";
include "../utilities/arithmetic.circom";
include "affinePoint.circom";
include "projectivePoint.circom";
include "../../../libs/node_modules/circomlib/circuits/comparators.circom";

// ========================================================================================================================
// MEMBERSHIP TESTS:

/**
* We are using montgomery elliptic curves with the defining equation:
* {(x,y)| By^2=x^3+Ax^2+x}.
*
* Will return 1 if the given point is a curve point and 0 otherwise;
*/
template isCurvePointAffine(A, B) {
    input AffinePoint() in;

    signal output out;

    signal xx <== in.x**2;
    signal yy <== in.y**2;

    component ifThenElse = ifThenElse();
    component isZero = IsZero();

    isZero.in <== in.x*xx + A*xx + in.x - B*yy;

    ifThenElse.ifV <== isZero.out;
    ifThenElse.elseV <== 1;
    ifThenElse.cond <== in.notInfty;

    out <== ifThenElse.out;

    // Test:
    // out === 1;
}

/**
* The group law becomes: 
* {(X:Y:Z)| BY^2*Z=X^3+AX^2*Z+XZ^2}
* 
* Will return 1 if the given point is a curve point and 0 otherwise;
*/
template isCurvePointProjective(A, B) {
    input ProjectivePoint() in;

    signal output out;

    signal XX <== in.X*in.X;
    signal YY <== in.Y*in.Y;
    signal ZZ <== in.Z*in.Z;
    signal YYZ <== YY*in.Z;
    signal XXX <== XX*in.X;
    signal XXZ <== XX*in.Z;
    signal XZZ <== in.X*ZZ;

    component isZero = IsZero();
    isZero.in <== XXX + A*XXZ + XZZ - B*YYZ;

    out <== isZero.out;
}
