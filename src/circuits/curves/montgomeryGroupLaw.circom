pragma circom 2.2.1;

include "../utilities/branching.circom";
include "../utilities/arithmetic.circom";
include "affinePoint.circom";
include "projectivePoint.circom";
include "conversionsPointRepresentations.circom";
include "../../../libs/node_modules/circomlib/circuits/comparators.circom";

// ========================================================================================================================
// GROUP LAW CASES:

template tangentRuleAffine(A, B) {
    input AffinePoint() p;

    output AffinePoint() out;

    signal xx <== p.x*p.x;
    component division = divisionSafe();
    division.numerator <== 3*xx + 2*A*p.x + 1;
    division.denominator <== 2*B*p.y;
    signal fractionSq <== division.out*division.out;
    out.x <== fractionSq*B - 2*p.x - A;

    signal xDif <== p.x-out.x;
    out.y <== division.out*xDif - p.y;

    out.notInfty <== 1;
}

/**
* Same as tangent rule, but only works, if p.y != 0.
*/
template tangent_rule_no_checks(A, B) {
    input AffinePoint() p;

    output AffinePoint() out;

    signal xx <== p.x*p.x;
    component division = division();
    division.numerator <== 3*xx + 2*A*p.x + 1;
    division.denominator <== 2*B*p.y;
    signal fractionSq <== division.out*division.out;
    out.x <== fractionSq*B - 2*p.x - A;

    signal xDif <== p.x-out.x;
    out.y <== division.out*xDif - p.y;

    out.notInfty <== 1;
}


template chordRuleAffine(A, B) {
    input AffinePoint() p;
    input AffinePoint() q;

    output AffinePoint() out;

    component division = divisionSafe();
    division.numerator <== q.y - p.y;
    division.denominator <== q.x - p.x;
    signal fractionSq <== division.out*division.out;
    out.x <== fractionSq*B - (p.x + q.x) - A;

    signal xDif <== p.x-out.x;
    out.y <== division.out*xDif - p.y;

    out.notInfty <== 1;
}

/**
* Same as chord rule, but only works, if q.x-p.x != 0.
*/
template chord_rule_no_checks(A, B) {
    input AffinePoint() p;
    input AffinePoint() q;

    output AffinePoint() out;

    component division = division();
    division.numerator <== q.y - p.y;
    division.denominator <== q.x - p.x;
    signal fractionSq <== division.out*division.out;
    out.x <== fractionSq*B - (p.x + q.x) - A;

    signal xDif <== p.x-out.x;
    out.y <== division.out*xDif - p.y;

    out.notInfty <== 1;
}

// ========================================================================================================================
// GROUP LAW:

/**
* Implements the addition of two points given in affine representation. (Using the group law as presented in MoonMath, 5.2)
*/
template addAffine(A, B) {
    input AffinePoint() p;
    input AffinePoint() q;

    output AffinePoint() out;

    component groupLawCases = switchCaseAffine(4);
    component serializep = serializeAffine();
    component serializeq = serializeAffine();
    serializep.in <== p;
    serializeq.in <== q;

    signal selector[3]; // Selects which of the cases of the group law to take.
    AffinePoint() cases[4]; //The result of the group law in the different cases.

    selector[0] <== 1 - p.notInfty*q.notInfty; // If one of the points is infty, we need to output the other as the result
    component deserialize = deserializeAffine();
    component ifPInftyThenQElseP = ifThenElseMulti(3);
    ifPInftyThenQElseP.cond <== 1-p.notInfty;
    ifPInftyThenQElseP.ifV <== serializeq.out;
    ifPInftyThenQElseP.elseV <== serializep.out;
    deserialize.in <== ifPInftyThenQElseP.out;
    cases[0] <== deserialize.out;

    component isNegation = IsZero();
    isNegation.in <== p.y+q.y;
    selector[1] <== (1-selector[0])*isNegation.out; // If not Case 1 and the y coordiantes are negations of each other, we need to output infty as the result.
    component infty = inftyAffine();
    cases[1] <== infty.out;

    component equalsx = IsZero();
    component equalsy = IsZero();
    equalsx.in <== p.x-q.x;
    equalsy.in <== p.y-q.y;
    signal equals <== equalsx.out * equalsy.out;
    signal selectorNot01 <== (1-selector[1])*(1-selector[0]);
    selector[2] <== selectorNot01*equals; // If the points are the same, we need to apply the tangent rule;
    component tangentRule = tangentRuleAffine(A, B);
    tangentRule.p <== p;
    cases[2] <== tangentRule.out;

    component chordRule = chordRuleAffine(A, B);
    chordRule.p <== p;
    chordRule.q <== q;
    cases[3] <== chordRule.out;

    groupLawCases.in <== cases;
    groupLawCases.cond <== selector;

    out <== groupLawCases.out;

    // Test:
    // input AffinePoint() test;
    // out === test;
}

template addProjective(A, B) {
    input ProjectivePoint() P;
    input ProjectivePoint() Q;

    output ProjectivePoint() out;

    component convertToAffineP = projectiveToAffine();
    component convertToAffineQ = projectiveToAffine();
    component affineAdder = addAffine(A, B);
    component convertToProjectiveRes = affineToProjective();

    convertToAffineP.in <== P;
    convertToAffineQ.in <== Q;

    affineAdder.p <== convertToAffineP.out;
    affineAdder.q <== convertToAffineQ.out;

    convertToProjectiveRes.in <== affineAdder.out;
    out <== convertToProjectiveRes.out;

    // Test:
    // input ProjectivePoint() test;
    // out === test;
}

/**
* Computes the addition of montgomery curve points p and q.
*
* CAUTION: Only works, if p is not the point at infinity and q is not p or -p 
* (Then, we also have q.x != p.x.)
*/ 
template montgomery_group_law_restricted(A, B) {
    input AffinePoint() p;
    input AffinePoint() q;

    output AffinePoint() out;

    component chord_rule = chord_rule_no_checks(A, B);
    chord_rule.p <== p;
    chord_rule.q <== q;

    component if_else = ifThenElseMulti(2);
    if_else.cond <== q.notInfty;
    if_else.ifV[0] <== chord_rule.out.x;
    if_else.ifV[1] <== chord_rule.out.y;
    if_else.elseV[0] <== p.x;
    if_else.elseV[1] <== p.y;

    out.x <== if_else.out[0];
    out.y <== if_else.out[1];
    out.notInfty <== 1;
}

/**
* Computes the addition of montgomery curve points p and q.
*
* CAUTION: Only works, if p is not the point at infinity and q is not p. 
*/ 
template montgomery_group_law_without_tangent(A, B) {
    input AffinePoint() p;
    input AffinePoint() q;

    output AffinePoint() out;

    component chord_rule = chordRuleAffine(A, B);
    chord_rule.p <== p;
    chord_rule.q <== q;

    component is_negation = IsZero();
    is_negation.in <== p.y+q.y;

    component switch_case = switchCaseAffine(3);
    switch_case.cond[0] <== 1-q.notInfty; // Case q = infinity
    switch_case.cond[1] <== is_negation.out; // Case q = -p
    switch_case.in[0] <== p; // p + infinity = p
    switch_case.in[1].x <== 0;
    switch_case.in[1].y <== 0;
    switch_case.in[1].notInfty <== 0; // p - p = infinity
    switch_case.in[2] <== chord_rule.out;

    out <== switch_case.out;
}

/**
* Computes the addition of montgomery curve points p and q.
*
* CAUTION: Only works, if p and q are not the point at infinity.
*/
template group_law_without_infinity_cases(A, B) {
    input AffinePoint() p;
    input AffinePoint() q;

    output AffinePoint() out;

    component is_equal_x = IsZero();
    is_equal_x.in <== p.x - q.x;
    component is_negation_y = IsZero();
    is_negation_y.in <== p.y + q.y;

    signal is_inv <== is_equal_x.out * is_negation_y.out;
    signal is_eq <== is_equal_x.out - is_inv; // <=>  is_equal_x.out * (1-is_negation_y.out)

    component tangent_rule = tangentRuleAffine(A,B);
    tangent_rule.p.x <== p.x;
    tangent_rule.p.y <== p.y;
    tangent_rule.p.notInfty <== p.notInfty;

    component chord_rule = chord_rule_no_checks(A, B);
    chord_rule.p.x <== p.x + is_equal_x.out; // Avoids failure in case p.x = q.x without extra constraints
    chord_rule.p.y <== p.y;
    chord_rule.p.notInfty <== p.notInfty;
    chord_rule.q <== q;

    component switch_case = switchCaseAffine(3);
    switch_case.cond[0] <== is_inv; // Case q = -p
    switch_case.cond[1] <== is_eq; // Case q = p (If p.x = q.x, the only possibilities are p.y = q.y and p.y = -q.y)

    switch_case.in[0].x <== 0;
    switch_case.in[0].y <== 0;
    switch_case.in[0].notInfty <== 0; // p - p = infinity
    switch_case.in[1] <== tangent_rule.out;
    switch_case.in[2] <== chord_rule.out;

    out <== switch_case.out;
}

/**
* Computes the addition of montgomery curve points p and q. (Using the group law as presented in MoonMath, 5.2)
*/
template group_law(A, B) {
    input AffinePoint() p;
    input AffinePoint() q;

    output AffinePoint() out;

    signal is_inf_p <== 1-p.notInfty;
    signal is_inf_q <== 1-q.notInfty;
    signal both_inf <== is_inf_p * is_inf_q;
    signal neither_inf <== 1-(is_inf_p + is_inf_q - both_inf);

    component is_equal_x = IsZero();
    is_equal_x.in <== p.x - q.x;
    component is_negation_y = IsZero();
    is_negation_y.in <== p.y + q.y;

    signal tmp <== neither_inf * is_equal_x.out;
    signal is_inv <== tmp * is_negation_y.out; // <=> neither_inf * is_equal_x.out * is_negation_y.out
    signal is_eq <== tmp - is_inv; // <=>  neither_inf * is_equal_x.out * (1-is_negation_y.out)

    component tangent_rule = tangentRuleAffine(A,B);
    tangent_rule.p.x <== p.x;
    tangent_rule.p.y <== p.y;
    tangent_rule.p.notInfty <== p.notInfty;

    component chord_rule = chord_rule_no_checks(A, B);
    chord_rule.p.x <== p.x + is_equal_x.out; // Avoids failure in case p.x = q.x without extra constraints
    chord_rule.p.y <== p.y;
    chord_rule.p.notInfty <== p.notInfty;
    chord_rule.q <== q;

    component switch_case_xy = switchCaseMulti(5, 2);
    switch_case_xy.cond[0] <== is_inf_p - both_inf;
    switch_case_xy.cond[1] <== is_inf_q; // Select p, if both points are infinity
    switch_case_xy.cond[2] <== is_inv; // Case q = -p
    switch_case_xy.cond[3] <== is_eq; // Case q = p (If p.x = q.x, the only possibilities are p.y = q.y and p.y = -q.y)

    switch_case_xy.in[0][0] <== q.x;
    switch_case_xy.in[0][1] <== q.y;
    switch_case_xy.in[1][0] <== p.x;
    switch_case_xy.in[1][1] <== p.y;
    switch_case_xy.in[2][0] <== 0;
    switch_case_xy.in[2][1] <== 0;
    switch_case_xy.in[3][0] <== tangent_rule.out.x;
    switch_case_xy.in[3][1] <== tangent_rule.out.y;
    switch_case_xy.in[4][0] <== chord_rule.out.x;
    switch_case_xy.in[4][1] <== chord_rule.out.y;

    out.x <== switch_case_xy.out[0];
    out.y <== switch_case_xy.out[1];
    out.notInfty <== 1-(both_inf + is_inv); // both_inf and is_inv at the same time is not possible
}

// component main = tangentRuleAffine(126932, 1);
// component main = chordRuleAffine(126932, 1);
// component main = montgomery_group_law_restricted(126932, 1);
// component main = addAffine(126932, 1);
// component main = montgomery_group_law_without_tangent(126932, 1);
// component main = group_law_without_infinity_cases(126932, 1);
// component main = chord_rule_affine_no_checks(126932, 1);
// component main = group_law(126932, 1);