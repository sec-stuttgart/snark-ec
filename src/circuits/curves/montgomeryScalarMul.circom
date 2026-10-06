pragma circom 2.2.1;

include "../utilities/branching.circom";
include "../utilities/arithmetic.circom";
include "../utilities/bitify.circom";
include "../utilities/asserts.circom";
include "affinePoint.circom";
include "projectivePoint.circom";
include "conversionsPointRepresentations.circom";
include "montgomeryLadder.circom";
include "montgomeryGroupLaw.circom";
include "yRecovery.circom";
include "../../../libs/node_modules/circomlib/circuits/comparators.circom";
include "../../../libs/node_modules/circomlib/circuits/gates.circom";
include "../../../libs/node_modules/circomlib/circuits/bitify.circom";

// ========================================================================================================================
// SCALAR MULTIPLICATION

/**
* Computes mP. (Where m is later represented as a bit string of length n.)
*/
template scalarMulAffine(n, A, B) {
    input signal m;
    input AffinePoint() P;

    output AffinePoint() out;

    component convertToProjective = affineToProjective();
    convertToProjective.in <== P;
    ProjectivePoint() projectiveP <== convertToProjective.out;

    component scalarMulProjective = scalarMulProjective(n, A, B);
    scalarMulProjective.m <== m;
    scalarMulProjective.P <== projectiveP;

    component convertToAffine = projectiveToAffine();
    convertToAffine.in <== scalarMulProjective.out;
    out <== convertToAffine.out;

    // Test:
    input AffinePoint() test;
    test === out;
}

/**
* Computes mP. (Where m is later represented as a bit string of length n.)
*/
template scalarMulProjective(n, A, B) {
    input signal m;
    input ProjectivePoint() P;

    output ProjectivePoint() out;

    component toBits = Num2Bits(n);
    toBits.in <== m;
    signal mBits[n] <== toBits.out;

    component ladder = ladderProjective(n, A);
    ladder.mulBits <== mBits;
    ladder.P <== P;
    ProjectivePoint() mP <== ladder.r0Final;
    ProjectivePoint() mPlus1P <== ladder.r1Final;

    component yRecovery = yRecoveryProjective(A, B);
    yRecovery.P <== P;
    yRecovery.Q <== mP;
    yRecovery.PPlusQ <== mPlus1P;

    ProjectivePoint() mPReconstructed <== yRecovery.out;

    component selectEnabled = selectEnabledProjective(4);
    component getInfty = inftyProjective();
    component getZero = zeroProjective();

    // Case 1: If P is infty, then mP is also infty.
    component isPInfty = isInftyProjective();
    isPInfty.in <== P;
    signal case0 <== isPInfty.out;
    selectEnabled.s[0] <== case0;
    selectEnabled.in[0] <== getInfty.out;

    // Case 2: If P is zero and the exponent is odd, then the output is zero.
    component isPZero = isZeroProjective();
    isPZero.in <== P;
    signal ismOdd <== mBits[0];
    signal case1 <== isPZero.out * ismOdd;
    selectEnabled.s[1] <== case1;
    selectEnabled.in[1] <== getZero.out;

    // Case 3: If P is zero and the exponent is even, then the output is infty.
    signal case2 <== isPZero.out * (1-ismOdd);
    selectEnabled.s[2] <== case2;
    selectEnabled.in[2] <== getInfty.out;

    // Case 4: Otherwise, the result mPReconstructed is correct.
    signal tmp <== (1-case1) * (1-case2);
    signal case3 <== tmp * (1-case0);
    selectEnabled.s[3] <== case3;
    selectEnabled.in[3] <== mPReconstructed;

    out <== selectEnabled.out;

    // Test:
    // input ProjectivePoint() test;
    // test === out;
}

/**
* Computes the m * P, where m=[m_0,m_1,\dots, m_{n-1}] is given as a representation to base "base" in LSB order. (For brevity, we use b to denote base here)
* Here, m_i = [m_{i,0}, \dots, m_{i,b-1}] is a unary coding of m_i with m_{i,j} = 1 exactly if m_i = j
* Furthermore, powers_array provides 
*   [   
*       [e+P, 1*P+P, 2*1*P+P,\dots, (b-1)*1*P+P],
*       [e+P, b*P+P, 2*b*P+P,\dots, (b-1)*b*P+P],
*       [e+P, (b^2)*P+P, 2*(b^2)*P+P,\dots, (b-1)*(b^2)*P+P],
*       \dots,
*       [e+P, (b^{n-3})*P+P, 2*(b^{n-3})*P+P,\dots, (b-1)*(b^{n-3})*P+P],
* 
*       [e+(b^{n-2}*P), (b^{n-2})*P+(b^{n-2}*P), 2*(b^{n-2})*P+(b^{n-2}*P),\dots, (b-1)*(b^{n-2})*P+(b^{n-2}*P)],
*       [e-(b^{n-2}*P)-(n-2)*P, (b^{n-1})*P-(b^{n-2}*P)-(n-2)*P, 2*(b^{n-1})*P-(b^{n-2}*P)-(n-2)*P,\dots, (b-1)*(b^{n-1})*P-(b^{n-2}*P)-(n-2)*P]
*   ]
*
* CAUTION: Point P must not be infinity.
*/
template montgomery_scalar_mul_arbitrary_base_fixed_powers(base, n_digits, A, B, powers_array) {
    input signal m[n_digits][base];

    output AffinePoint() out;
    
    AffinePoint powers[n_digits][base];
    AffinePoint intermediate_results[n_digits-1];

    component adders[n_digits-2];
    component switch_case[n_digits];

    // Select correct powers to multiply with
    for(var i = 0; i < n_digits; i++) {
        switch_case[i] = switch_case_affine(base);

        for(var j = 0; j < base; j++) {
            powers[i][j].x <== powers_array[i][j][0];
            powers[i][j].y <== powers_array[i][j][1];
            powers[i][j].notInfty <== powers_array[i][j][2];
        }
        switch_case[i].in <== powers[i];
        switch_case[i].cond <== m[i];
    }

    // Initialize intermediate product
    intermediate_results[n_digits-2] <== switch_case[n_digits-2].out;

    // Multiply with selected powers
    for(var i = n_digits-3; i >= 0; i--) {
        adders[i] = chord_rule_no_checks(A, B);
        adders[i].p <== intermediate_results[i+1];
        adders[i].q <== switch_case[i].out;
        intermediate_results[i] <== adders[i].out;
    }

    component final_adder = group_law_without_infinity_cases(A, B);
    final_adder.p <== intermediate_results[0];
    final_adder.q <== switch_case[n_digits-1].out;
    
    out <== final_adder.out;
}

/*
component main = montgomery_scalar_mul_arbitrary_base_fixed_powers(4, 5, 126932, 1, 
    [
        [[0,0,0],[1,1,1],[1,1,1],[1,1,1]],
        [[0,0,0],[1,1,1],[1,1,1],[1,1,1]],
        [[0,0,0],[1,1,1],[1,1,1],[1,1,1]],
        [[0,0,0],[1,1,1],[1,1,1],[1,1,1]],
        [[0,0,0],[1,1,1],[1,1,1],[1,1,1]]
    ]);
*/

/*
component main = montgomery_scalar_mul_arbitrary_base_fixed_powers(4, 2, 126934, 1, 
    [
        [[0,0,0],[1,1,1],[1,1,1],[1,1,1]],
        [[0,0,0],[1,1,1],[1,1,1],[1,1,1]]
    ]);
*/

/*
component main = montgomery_scalar_mul_arbitrary_base_fixed_powers(4, 1, 126934, 1, 
    [
        [[0,0,0],[1,1,1],[1,1,1],[1,1,1]]
    ]);
*/
