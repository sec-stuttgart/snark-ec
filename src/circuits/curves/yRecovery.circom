pragma circom 2.2.1;

include "../utilities/branching.circom";
include "../utilities/arithmetic.circom";
include "affinePoint.circom";
include "projectivePoint.circom";
include "conversionsPointRepresentations.circom";
include "../../../libs/node_modules/circomlib/circuits/comparators.circom";
include "../../../libs/node_modules/circomlib/circuits/gates.circom";

// ========================================================================================================================
// OKEYA-SAKURAI-Y-RECOVERY

/**
* y-Recovery of the point Q according to okeya-sakurai ("Efficient Elliptic Curve Cryptosystems from a Scalar Multiplication Algorithm with Recovery of the y-Coordinate on a Montgomery-Form Elliptic Curve") (Theorem 2).
*/
template okeyaSakuraiYRecoveryAffine(A, B) {
    input AffinePoint() P;
    input AffinePoint() Q;
    input AffinePoint() PPlusQ;

    output AffinePoint() out; // Point with reconstructed y-coordinate

    signal denominator <== 2*B*P.y;
    signal tmp1 <== Q.x * P.x;
    signal tmp2 <== Q.x + P.x + 2*A;
    signal tmp3 <== (tmp1 + 1) * tmp2;
    signal tmp4 <== (Q.x - P.x) * (Q.x - P.x);
    signal tmp5 <== tmp4 * PPlusQ.x;
    signal numerator <== tmp3 - 2*A - tmp5;

    component division = division();
    division.numerator <== numerator;
    division.denominator <== denominator;

    out.x <== Q.x;
    out.y <== division.out;
    out.notInfty <== 1;
}

/**
* y-Recovery of the point Q according to okeya-sakurai ("Efficient Elliptic Curve Cryptosystems from a Scalar Multiplication Algorithm with Recovery of the y-Coordinate on a Montgomery-Form Elliptic Curve") (Algorithm 1).
* 
* We are using the notation x_n to notate the (n+1)-th assignment of variable x.
*/
template okeyaSakuraiYRecoveryProjective(A, B) {
    input ProjectivePoint() P;
    input ProjectivePoint() Q;
    input ProjectivePoint() PPlusQ;

    output ProjectivePoint() out; // Point with reconstructed y-coordinate

    signal t1_0 <== P.X * Q.Z;
    signal t2_0 <== Q.X + t1_0;
    signal t3_0 <== Q.X - t1_0;
    signal t3_1 <== t3_0 * t3_0;
    signal t3_2 <== t3_1 * PPlusQ.X;
    signal t1_1 <== 2*A * Q.Z;
    signal t2_1 <== t2_0 + t1_1;
    signal t4_0 <== P.X * Q.X;
    signal t4_1 <== t4_0 + Q.Z;
    signal t2_2 <== t2_1 * t4_1;
    signal t1_2 <== t1_1 * Q.Z;
    signal t2_3 <== t2_2 - t1_2;
    signal t2_4 <== t2_3 * PPlusQ.Z;
    out.Y <== t2_4 - t3_2;
    signal t1_3 <== 2*B * P.Y;
    signal t1_4 <== t1_3 * Q.Z;
    signal t1_5 <== t1_4 * PPlusQ.Z;
    out.X <== t1_5 * Q.X;
    out.Z <== t1_5 * Q.Z;
}

// ========================================================================================================================
// Y-RECOVERY

/**
* Checks whether the preconditions for Okeya-Sakurai are fulfilled and computes y accordingly.
*/
template yRecoveryProjective(A, B) {
    input ProjectivePoint() P;
    input ProjectivePoint() Q;
    input ProjectivePoint() PPlusQ;

    output ProjectivePoint() out; // Point with reconstructed y-coordinate

    ProjectivePoint() normP;
    ProjectivePoint() normQ;
    component normalizeP = normalizeProjective();
    component normalizeQ = normalizeProjective();
    component normalizeRecovered = normalizeProjective();
    normalizeP.in <== P;
    normalizeQ.in <== Q;
    normP <== normalizeP.out;
    normQ <== normalizeQ.out;

    component okeyaSakurai = okeyaSakuraiYRecoveryProjective(A, B);
    okeyaSakurai.P <== P;
    okeyaSakurai.Q <== Q;
    okeyaSakurai.PPlusQ <== PPlusQ;

    ProjectivePoint() recoveredQ <== okeyaSakurai.out;
    normalizeRecovered.in <== recoveredQ;
    ProjectivePoint() normRecoveredQ <== normalizeRecovered.out;

    component ifThenElse = ifThenElseProjective();

    // Infty tests
    // Output -P if PPlusQ.z is 0, Q is not infty and P.X/P.Z = Q.X/Q.Z
    component testInftyPPlusQ = isInftyProjective();
    testInftyPPlusQ.in <== PPlusQ;

    component testEquality = IsEqual();
    testEquality.in[0] <== normP.X;
    testEquality.in[1] <== normQ.X;

    component and = AND();
    and.a <== testInftyPPlusQ.out;
    and.b <== testEquality.out;
    signal isQNegatedP <== and.out;

    ProjectivePoint() minusP; // Normalized to minusP.Z=1
    minusP.X <== normP.X;
    minusP.Y <== -normP.Y;
    minusP.Z <== 1;
    ifThenElse.cond <== isQNegatedP;
    ifThenElse.ifV <== minusP;

    // Otherwise, just normalize the recovered Q computed by Okeya-Sakurai
    ifThenElse.elseV <== normRecoveredQ;

    out <== ifThenElse.out;
}
