pragma circom 2.2.1;
include "../utilities/branching.circom";
include "../utilities/arithmetic.circom";
include "../utilities/bitify.circom";
include "affinePoint.circom";
include "projectivePoint.circom";
include "conversionsPointRepresentations.circom";
include "../../../libs/node_modules/circomlib/circuits/comparators.circom";
// ========================================================================================================================
// XADD, XMUL PSEUDOOPERATIONS:

/**
* According to "Montgomery Curves and the Montgomery ladder". (Theorem 4.3)
* CAUTION: Does not check inputs for infty.
*/
template xAddAffine() {
    input AffinePoint() P;
    input AffinePoint() Q;
    input AffinePoint() PMinusQ;
    output AffinePoint() out;
    signal tmpNumerator <== P.x*Q.x - 1;
    signal numerator <== tmpNumerator * tmpNumerator;
    signal tmpDenominator <== (P.x - Q.x) * (P.x - Q.x);
    signal denominator <== PMinusQ.x * tmpDenominator;
    component division = division();
    division.numerator <== numerator;
    division.denominator <== denominator;
    out.x <== division.out;
    out.y <== 0;
    out.notInfty <== 1;
}

/**
* According to "Montgomery Curves and the Montgomery ladder". (Theorem 4.1)
* CAUTION: Does not check input for infty.
*/
template xDblAffine(A) {
    input AffinePoint() P;
    output AffinePoint() out;
    signal xSquare <== P.x * P.x;
    signal numerator <== (xSquare - 1) * (xSquare - 1);
    signal denominator <== 4*P.x*(xSquare + A*P.x + 1);
    component division = division();
    division.numerator <== numerator;
    division.denominator <== denominator;
    out.x <== division.out;
    out.y <== 0;
    out.notInfty <== 1;
}

/**
* According to "Montgomery curves and their arithmetic" (Equation (9)).
* We are using the variable notation x_n for the (n+1)-th assignment of a value to the variable x in the paper.
* CAUTION: Does not check inputs for infty.
*/
template xAddProjective() {
    input ProjectivePoint() P;
    input ProjectivePoint() Q;
    input ProjectivePoint() PMinusQ;
    output ProjectivePoint() out;
    signal tmp1 <== (P.X - P.Z) * (Q.X + Q.Z);
    signal tmp2 <== (P.X + P.Z) * (Q.X - Q.Z);
    signal tmpX <== (tmp1 + tmp2) * (tmp1 + tmp2);
    signal tmpZ <== (tmp1 - tmp2) * (tmp1 - tmp2);
    out.X <== PMinusQ.Z * tmpX;
    out.Y <== 0;
    out.Z <== PMinusQ.X * tmpZ;
}

/**
* According to "Montgomery curves and their arithmetic" (Equation (10)).
* CAUTION: Does not check input for infty.
*/
template xDblProjective(A) {
    input ProjectivePoint() P;
    output ProjectivePoint() out;
    signal tmp1 <== (P.X + P.Z) * (P.X + P.Z);
    signal tmp2 <== (P.X - P.Z) * (P.X - P.Z);
    signal tmpZ1 <== tmp1 - tmp2; // 4*P_X*P_Z
    signal tmpZ2 <== tmp2 + ((A + 2)/4) * tmpZ1;
    
    out.X <== tmp1 * tmp2;
    out.Y <== 0;
    out.Z <== tmpZ1 * tmpZ2;
}
template xDblProjectivePadding(A) {
    input ProjectivePoint() P;
    input signal isNotPadding;
    output ProjectivePoint() out;
    component xDbl = xDblProjective(A);
    xDbl.P <== P;
    out.X <== xDbl.out.X * isNotPadding;
    out.Y <== 0;
    out.Z <== xDbl.out.Z * isNotPadding;
}

// ========================================================================================================================
// MONTGOMERY LADDER:
/**
* === !NOT USED! ===
* Computes the xCoordinate of the scalar multiplication mP.
* The bits are required to be in LSB order. Last bit is assumed to be 1.
* According to "Montgomery curves and their arithmetic", Algorithm 4.
*/
template ladderAffine(n, A) {
    input signal mulBits[n];
    input AffinePoint() P;
    output AffinePoint() r0Final;
    output AffinePoint() r1Final;
    AffinePoint() r0[n];
    AffinePoint() r1[n];
    component adders[n];
    component doublersR0[n];
    component doublersR1[n];
    component doublerInitial = xDblAffine(A);
    component ifThenElseR0[n];
    component ifThenElseR1[n];
    r0[n-1] <== P;
    doublerInitial.P <== P;
    r1[n-1] <== doublerInitial.out;
    for(var i = n-2; i >= 0; i--) {
        adders[i] = xAddAffine();
        doublersR0[i] = xDblAffine(A);
        doublersR1[i] = xDblAffine(A);
        ifThenElseR0[i] = ifThenElse();
        ifThenElseR1[i] = ifThenElse();
        adders[i].P <== r1[i+1];
        adders[i].Q <== r0[i+1];
        adders[i].PMinusQ <== P; // Since r1 is always (m+1)*P and r0 is m*P for some P.
        doublersR0[i].P <== r0[i+1];
        doublersR1[i].P <== r1[i+1];
        
        ifThenElseR0[i].ifV <== adders[i].out.x;
        ifThenElseR0[i].elseV <== doublersR0[i].out.x;
        ifThenElseR0[i].cond <== mulBits[i];
        r0[i].x <== ifThenElseR0[i].out;
        r0[i].y <== 0;
        r0[i].notInfty <== 1;
        ifThenElseR1[i].ifV <== doublersR1[i].out.x;
        ifThenElseR1[i].elseV <== adders[i].out.x;
        ifThenElseR1[i].cond <== mulBits[i];
        r1[i].x <== ifThenElseR1[i].out;
        r1[i].y <== 0;
        r1[i].notInfty <== 1;
    }
    r0Final <== r0[0];
    r1Final <== r1[0];
}

/**
* Computes the XCoordinate of the scalar multiplication mP.
* The bits are required to be in LSB order.
* According to "Montgomery curves and their arithmetic", Algorithm 4. 
* To allow for mulBits where the MSB is not 1, r0, r1 are initialized with infty, P as outlined in 5.3.
* Here, infty is (1:0:0) to work with the pseudooperations xAdd, XDbl
*/
template ladderProjective(n, A) {
    input signal mulBits[n];
    input ProjectivePoint() P;
    output ProjectivePoint() r0Final;
    output ProjectivePoint() r1Final;
    ProjectivePoint() r0[n+1];
    ProjectivePoint() r1[n+1];
    component adders[n];
    component doublersR0[n];
    component doublersR1[n];
    // Special representation of infty for montgomery ladder (otherwise the pseudooperations don't work)
    ProjectivePoint() infty;
    infty.X <== 1;
    infty.Y <== 0;
    infty.Z <== 0;
    component ifThenElseR0[n];
    component ifThenElseR1[n];
    r0[n] <== infty;
    r1[n] <== P;
    for(var i = n-1; i >= 0; i--) {
        adders[i] = xAddProjective();
        doublersR0[i] = xDblProjective(A);
        doublersR1[i] = xDblProjective(A);
        ifThenElseR0[i] = ifThenElseMulti(2);
        ifThenElseR1[i] = ifThenElseMulti(2);
        adders[i].P <== r1[i+1];
        adders[i].Q <== r0[i+1];
        adders[i].PMinusQ <== P; // Since r1 is always (m+1)*P and r0 is m*P for some m.
        doublersR0[i].P <== r0[i+1];
        doublersR1[i].P <== r1[i+1];
        
        ifThenElseR0[i].ifV[0] <== adders[i].out.X;
        ifThenElseR0[i].ifV[1] <== adders[i].out.Z;
        ifThenElseR0[i].elseV[0] <== doublersR0[i].out.X;
        ifThenElseR0[i].elseV[1] <== doublersR0[i].out.Z;
        ifThenElseR0[i].cond <== mulBits[i];
        r0[i].X <== ifThenElseR0[i].out[0];
        r0[i].Y <== 0;
        r0[i].Z <== ifThenElseR0[i].out[1];
        ifThenElseR1[i].ifV[0] <== doublersR1[i].out.X;
        ifThenElseR1[i].ifV[1] <== doublersR1[i].out.Z;
        ifThenElseR1[i].elseV[0] <== adders[i].out.X;
        ifThenElseR1[i].elseV[1] <== adders[i].out.Z;
        ifThenElseR1[i].cond <== mulBits[i];
        r1[i].X <== ifThenElseR1[i].out[0];
        r1[i].Y <== 0;
        r1[i].Z <== ifThenElseR1[i].out[1];
    }
    r0Final <== r0[0];
    r1Final <== r1[0];

    // input ProjectivePoint() test;
    // test === r0Final;
}

/**
* === !NOT USED! ===
* Computes the XCoordinate of the scalar multiplication mP.
* The bits are required to be in LSB order.
* According to "Montgomery curves and their arithmetic", Algorithm 4.
*/
template ladderProjectivePaddedNaive(n, A) {
    input signal mulBits[n];
    input ProjectivePoint() P;
    output ProjectivePoint() r0Final;
    output ProjectivePoint() r1Final;
    component padBits = padBits(n);
    padBits.in <== mulBits;
    signal mulBitsPadded[n] <== padBits.out;
    ProjectivePoint() r0[n];
    ProjectivePoint() r1[n];
    component ifPaddingElse[n];
    component adders[n];
    component doublersR0[n];
    component doublersR1[n];
    component doublerInitial = xDblProjective(A);
    component muxR0[n];
    component muxR1[n];
    r0[n-1] <== P;
    doublerInitial.P <== P;
    r1[n-1] <== doublerInitial.out;
    for(var i = n-2; i >= 0; i--) {
        adders[i] = xAddProjective();
        doublersR0[i] = xDblProjective(A);
        doublersR1[i] = xDblProjective(A);
        muxR0[i] = muxMulti2(2);
        muxR1[i] = muxMulti2(2);
        adders[i].P <== r1[i+1];
        adders[i].Q <== r0[i+1];
        adders[i].PMinusQ <== P; // Since r1 is always (m+1)*P and r0 is m*P for some P.
        doublersR0[i].P <== r0[i+1];
        doublersR1[i].P <== r1[i+1];
        
        muxR0[i].in[0][0] <== doublersR0[i].out.X;
        muxR0[i].in[0][1] <== doublersR0[i].out.Z;
        muxR0[i].in[1][0] <== adders[i].out.X;
        muxR0[i].in[1][1] <== adders[i].out.Z;
        muxR0[i].in[2][0] <== r0[i+1].X;
        muxR0[i].in[2][1] <== r0[i+1].Z;
        muxR0[i].in[3][0] <== 0;
        muxR0[i].in[3][1] <== 0;
        muxR0[i].selector <== mulBitsPadded[i];
        r0[i].X <== muxR0[i].out[0];
        r0[i].Y <== 0;
        r0[i].Z <== muxR0[i].out[1];
        muxR1[i].in[0][0] <== adders[i].out.X;
        muxR1[i].in[0][1] <== adders[i].out.Z;
        muxR1[i].in[1][0] <== doublersR1[i].out.X;
        muxR1[i].in[1][1] <== doublersR1[i].out.Z;
        muxR1[i].in[2][0] <== r1[i+1].X;
        muxR1[i].in[2][1] <== r1[i+1].Z;
        muxR1[i].in[3][0] <== 0;
        muxR1[i].in[3][1] <== 0;
        muxR1[i].selector <== mulBitsPadded[i];
        r1[i].X <== muxR1[i].out[0];
        r1[i].Y <== 0;
        r1[i].Z <== muxR1[i].out[1];
    }
    r0Final <== r0[0];
    r1Final <== r1[0];
    log("\nResult:");
    log("X: ", r0Final.X);
    log("Y: ", r0Final.Y);
    log("Z: ", r0Final.Z);

    // input ProjectivePoint() test;
    // test === r0Final;
}

/**
* === !NOT USED! ===
* Computes the XCoordinate of the scalar multiplication mP.
* The bits are required to be in LSB order.
* According to "Montgomery curves and their arithmetic", Algorithm 4.
*/
template ladderProjectivePaddedConstraintReduced(n, A) {
    input signal mulBits[n];
    input ProjectivePoint() P;
    output ProjectivePoint() r0Final;
    output ProjectivePoint() r1Final;
    ProjectivePoint() r0[n];
    ProjectivePoint() r1[n];
    signal isNotPadding[n]; // Computes whether the corresponding bit of mulBits belongs to the padding or not
    component adders[n];
    component doublersR0[n];
    component doublersR1[n];
    component doublerInitial = xDblProjective(A);
    component ifThenElseR0[n];
    component ifThenElseR1[n];
    component ifThenElsePaddingR0[n];
    component ifThenElsePaddingR1[n];
    r0[n-1] <== P;
    doublerInitial.P <== P;
    r1[n-1] <== doublerInitial.out;
    isNotPadding[n-1] <== mulBits[n-1];
    log("Initial:");
    log("R0:");
    log("X: ", r0[n-1].X);
    log("Y: ", r0[n-1].Y);
    log("Z: ", r0[n-1].Z);
    log("R1:");
    log("X: ", r1[n-1].X);
    log("Y: ", r1[n-1].Y);
    log("Z: ", r1[n-1].Z);
    for(var i = n-2; i >= 0; i--) {
        adders[i] = xAddProjective();
        doublersR0[i] = xDblProjective(A);
        doublersR1[i] = xDblProjective(A);
        ifThenElseR0[i] = ifThenElseMulti(2);
        ifThenElseR1[i] = ifThenElseMulti(2);
        ifThenElsePaddingR0[i] = ifThenElseMulti(2);
        ifThenElsePaddingR1[i] = ifThenElseMulti(2);
        isNotPadding[i] <== mulBits[i] + isNotPadding[i+1] - mulBits[i]*isNotPadding[i+1];
        adders[i].P <== r1[i+1];
        adders[i].Q <== r0[i+1];
        adders[i].PMinusQ <== P; // Since r1 is always (m+1)*P and r0 is m*P for some P.
        doublersR0[i].P <== r0[i+1];
        doublersR1[i].P <== r1[i+1];
        
        ifThenElseR0[i].ifV[0] <== adders[i].out.X;
        ifThenElseR0[i].ifV[1] <== adders[i].out.Z;
        ifThenElseR0[i].elseV[0] <== doublersR0[i].out.X;
        ifThenElseR0[i].elseV[1] <== doublersR0[i].out.Z;
        ifThenElseR0[i].cond <== mulBits[i];
        ifThenElsePaddingR0[i].ifV[0] <== ifThenElseR0[i].out[0];
        ifThenElsePaddingR0[i].ifV[1] <== ifThenElseR0[i].out[1];
        ifThenElsePaddingR0[i].elseV[0] <== r0[n-1].X;
        ifThenElsePaddingR0[i].elseV[1] <== r0[n-1].Z;
        ifThenElsePaddingR0[i].cond <== isNotPadding[i+1];
        r0[i].X <== ifThenElsePaddingR0[i].out[0];
        r0[i].Y <== 0;
        r0[i].Z <== ifThenElsePaddingR0[i].out[1];
        ifThenElseR1[i].ifV[0] <== doublersR1[i].out.X;
        ifThenElseR1[i].ifV[1] <== doublersR1[i].out.Z;
        ifThenElseR1[i].elseV[0] <== adders[i].out.X;
        ifThenElseR1[i].elseV[1] <== adders[i].out.Z;
        ifThenElseR1[i].cond <== mulBits[i];
        ifThenElsePaddingR1[i].ifV[0] <== ifThenElseR1[i].out[0];
        ifThenElsePaddingR1[i].ifV[1] <== ifThenElseR1[i].out[1];
        ifThenElsePaddingR1[i].elseV[0] <== r1[n-1].X;
        ifThenElsePaddingR1[i].elseV[1] <== r1[n-1].Z;
        ifThenElsePaddingR1[i].cond <== isNotPadding[i+1];
        r1[i].X <== ifThenElsePaddingR1[i].out[0];
        r1[i].Y <== 0;
        r1[i].Z <== ifThenElsePaddingR1[i].out[1];
    }
    r0Final <== r0[0];
    r1Final <== r1[0];
    log("\nResult:");
    log("X: ", r0Final.X);
    log("Y: ", r0Final.Y);
    log("Z: ", r0Final.Z);

    // input ProjectivePoint() test;
    // test === r0Final;
}
