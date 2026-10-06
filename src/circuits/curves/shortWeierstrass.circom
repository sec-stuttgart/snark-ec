pragma circom 2.2.1;

include "../utilities/branching.circom";
include "../utilities/arithmetic.circom";
include "../utilities/bitify.circom";
include "../utilities/asserts.circom";
include "../../../libs/node_modules/circomlib/circuits/comparators.circom";
include "../../../libs/node_modules/circomlib/circuits/gates.circom";
include "../../../libs/node_modules/circomlib/circuits/bitify.circom";
include "affinePoint.circom";

/**
* Computes P + P, when P is not infinity.
*
* Curve: y^2 = x^3 + ax + b
*/
template tangent_rule_safe(a, b) {
    input AffinePoint() P;

    output AffinePoint() out;

    component div = divisionSafe();
    div.numerator <== 3*P.x*P.x + a;
    div.denominator <== 2*P.y;

    out.x <== div.out * div.out - 2*P.x;
    out.y <== div.out * (P.x - out.x) - P.y;
    out.notInfty <== 1;
}

/**
* Computes P + P, when P is not infinity.
*
* Curve: y^2 = x^3 + ax + b
*
* WARNING: Computation fails, if P.y = 0.
*/
template tangent_rule(a, b) {
    input AffinePoint() P;

    output AffinePoint() out;

    component div = division();
    div.numerator <== 3*P.x*P.x + a;
    div.denominator <== 2*P.y;

    out.x <== div.out * div.out - 2*P.x;
    out.y <== div.out * (P.x - out.x) - P.y;
    out.notInfty <== 1;
}

/**
* Computes P + P
*
* Curve: y^2 = x^3 + ax + b
*/ 
template double(a, b) {
    input AffinePoint() P;

    output AffinePoint() out;

    component div = division();
    div.numerator <== 3*P.x*P.x + a;
    div.denominator <== 2*P.y + 2*(1 - P.notInfty); // != 0 for prime modulus

    out.x <== div.out * div.out - 2*P.x;
    out.y <== div.out * (P.x - out.x) - P.y;
    out.notInfty <== P.notInfty;
}

/**
* Compute P + Q, when:
7*   - P not infinity
*   - Q not infinity
*   - Q not P
*   - Q not -P
*
* Curve: y^2 = x^3 + ax + b
*/
template chord_rule_safe() {
    input signal P[2];
    input signal Q[2];

    output signal out[2];

    component div = divisionSafe();
    div.numerator <== Q[1] - P[1];
    div.denominator <== Q[0] - P[0];

    out[0] <== div.out * div.out - P[0] - Q[0];
    out[1] <== div.out * (P[0] - out[0]) - P[1];
}

/**
* Compute P + Q, when:
*   - P not infinity
*   - Q not infinity
*   - Q not P
*   - Q not -P
*
* Curve: y^2 = x^3 + ax + b
*
* WARNING: Computation fails if P.x = Q.x.
*/
template chord_rule() {
    input signal P[2];
    input signal Q[2];

    output signal out[2];

    component div = division();
    div.numerator <== Q[1] - P[1];
    div.denominator <== Q[0] - P[0];

    out[0] <== div.out * div.out - P[0] - Q[0];
    out[1] <== div.out * (P[0] - out[0]) - P[1];
}

/**
* Compute P + Q, when:
*   - P not infinity
*   - Q not infinity
*
* Curve: y^2 = x^3 + ax + b
*/
template group_law_without_infinity_cases(a, b) {
    input AffinePoint() P;
    input AffinePoint() Q;

    output AffinePoint() out;

    component is_x_equal = IsZero();
    is_x_equal.in <== P.x - Q.x;
    component is_y_negated = IsZero();
    is_y_negated.in <== P.y + Q.y;
    component is_p_y_zero = IsZero();
    is_p_y_zero.in <== P.y;
    signal is_inverse <== is_x_equal.out * is_y_negated.out;
    signal is_equal <== is_x_equal.out - is_inverse;

    component tangent_rule = tangent_rule(a, b);
    tangent_rule.P.x <== P.x;
    tangent_rule.P.y <== P.y + is_p_y_zero.out;
    tangent_rule.P.notInfty <== P.notInfty;

    component chord_rule = chord_rule();
    chord_rule.P[0] <== P.x;
    chord_rule.P[1] <== P.y;
    chord_rule.Q[0] <== Q.x + is_x_equal.out;
    chord_rule.Q[1] <== Q.y;

    component switch_case_xy = switchCaseMulti(3, 2);
    switch_case_xy.cond[0] <== is_inverse; // Case q = -p
    switch_case_xy.cond[1] <== is_equal; // Case q = p
    switch_case_xy.in[0][0] <== 0;
    switch_case_xy.in[0][1] <== 0;
    switch_case_xy.in[1][0] <== tangent_rule.out.x;
    switch_case_xy.in[1][1] <== tangent_rule.out.y;
    switch_case_xy.in[2][0] <== chord_rule.out[0];
    switch_case_xy.in[2][1] <== chord_rule.out[1];

    out.x <== switch_case_xy.out[0];
    out.y <== switch_case_xy.out[1];
    out.notInfty <== 1-is_inverse;
}

/**
* Compute P + Q, when:
*
* Curve: y^2 = x^3 + ax + b
*/
template group_law(a, b) {
    input AffinePoint() P;
    input AffinePoint() Q;

    output AffinePoint() out;

    signal is_p_inf <== 1-P.notInfty;
    signal is_q_inf <== 1-Q.notInfty;
    signal both_inf <== is_p_inf * is_q_inf;
    signal none_inf <== 1-is_p_inf-is_q_inf+both_inf;
    component is_x_equal = IsZero();
    is_x_equal.in <== P.x - Q.x;
    component is_y_negated = IsZero();
    is_y_negated.in <== P.y + Q.y;
    component is_p_y_zero = IsZero();
    is_p_y_zero.in <== P.y;
    signal tmp <== is_x_equal.out * none_inf;
    signal is_inverse <== tmp * is_y_negated.out;
    signal is_equal <== tmp - is_inverse;

    component tangent_rule = tangent_rule(a, b);
    tangent_rule.P.x <== P.x;
    tangent_rule.P.y <== P.y + is_p_y_zero.out;
    tangent_rule.P.notInfty <== P.notInfty;

    component chord_rule = chord_rule();
    chord_rule.P[0] <== P.x;
    chord_rule.P[1] <== P.y;
    chord_rule.Q[0] <== Q.x + is_x_equal.out;
    chord_rule.Q[1] <== Q.y;

    component switch_case_xy = switchCaseMulti(5, 2);
    switch_case_xy.cond[0] <== is_p_inf - both_inf; // Case p = infinity and q != infinity
    switch_case_xy.cond[1] <== is_q_inf; // Case q = infinity
    switch_case_xy.cond[2] <== is_inverse; // Case q = -p
    switch_case_xy.cond[3] <== is_equal; // Case q = p
    switch_case_xy.in[0][0] <== Q.x;
    switch_case_xy.in[0][1] <== Q.y;
    switch_case_xy.in[1][0] <== P.x;
    switch_case_xy.in[1][1] <== P.y;
    switch_case_xy.in[2][0] <== 0;
    switch_case_xy.in[2][1] <== 0;
    switch_case_xy.in[3][0] <== tangent_rule.out.x;
    switch_case_xy.in[3][1] <== tangent_rule.out.y;
    switch_case_xy.in[4][0] <== chord_rule.out[0];
    switch_case_xy.in[4][1] <== chord_rule.out[1];

    out.x <== switch_case_xy.out[0];
    out.y <== switch_case_xy.out[1];
    out.notInfty <== 1-(both_inf + is_inverse);
}

/**
* Computes the m * P, where m=[m_0,m_1,\dots, m_{n-1}] is given as a representation to base "base" in LSB order. (For brevity, we use b to denote base here)
* Here, m_i = [m_{i,0}, \dots, m_{i,b-1}] is a unary coding of m_i with m_{i,j} = 1 exactly if m_i = j
* Furthermore, multiples_array provides 
*   [   
*       [e+P, 1*P+P, 2*1*P+P,\dots, (b-1)*1*P+P],
*       [e+P, b*P+P, 2*b*P+P,\dots, (b-1)*b*P+P],
7*       [e+P, (b^2)*P+P, 2*(b^2)*P+P,\dots, (b-1)*(b^2)*P+P],
*       \dots,
*       [e+P, (b^{n-4})*P+P, 2*(b^{n-4})*P+P,\dots, (b-1)*(b^{n-4})*P+P],
* 
*       [e+(b^{n-3})*P+(b-(n-3) mod b)*P, (b^{n-3})*P+(b^{n-3})*P+(b-(n-3) mod b)*P, 2*(b^{n-3})*P+(b^{n-3})*P+(b-(n-3) mod b)*P,\dots, (b-1)*(b^{n-3})*P+(b^{n-3})*P+(b-(n-3) mod b)*P]
*       [e+P, (b^{n-2})*P+b*P, 2*(b^{n-2})*P+b*P,\dots, (b-1)*(b^{n-2})*P+b*P],
*       [e-(b^{n-3})*P-(n-3)*P-(b-(n-3) mod b)*P, (b^{n-1})*P-(b^{n-3})*P-(n-3)*P-(b-(n-3) mod b)*P, 2*(b^{n-1})*P-(b^{n-3})*P-(n-3)*P-(b-(n-3) mod b)*P,\dots, (b-1)*(b^{n-1})*P-(b^{n-3})*P-(n-3)*P-(b-(n-3) mod b)*P]
*   ]
*
* CAUTION: 
*   - Point P must not be infinity.
*   - base >= 3, n_digits >= 4
*/

function addscalar_sw(g,h,a,b){
    var result[3];
    var aux;
    if (g[2] == 0){return h;}
    if (h[2] == 0){return g;}
    if ((g[0] == -h[0]) && (g[1] == -h[1])){
        result[0] = 0;
        result[1] = 0;
        result[2] = 0;
        return result;
    }
    if ((g[0] == h[0]) && (g[1] == h[1])){
        aux = 3*g[0]*g[0]+a;
        aux /= 2*g[1];
    } else {
        aux = h[1]-g[1];
        aux /= h[0]-g[0];
    }
    result[0] = aux*aux-g[0]-h[0];
    result[1] = aux*(g[0]-result[0])-g[1];
    result[2] = 1;
    return result;
}


template group_law_sw(){
    input signal P[2];
    input signal Q[2];
    output signal out[2];
    var result[3];

    signal b;
    b <-- (Q[1]-P[1])/(Q[0]-P[0]);
    b*(Q[0]-P[0]) === Q[1]-P[1];

    signal c,d;
    c <-- b*b-P[0]-Q[0];
    c + P[0] + Q[0] === b*b;
    d <-- b*(P[0]-c)-P[1];
    d + P[1] === b*(P[0]-c);
    out[0] <== c;
    out[1] <== d;
}

template scalar_mul(swa, swb, b, k, multiples_array) {
    input signal m[k][b];
    output AffinePoint() out;
    var sum = 0;
    var sumin = 0;
    var shift = 3;
    signal s[k*b];
    for (var i = 0; i<k; i++){
        for (var j = 0; j<b; j++){
                s[i*b+j] <== m[i][j];
        }
    }

    var scale =1;
    if (b==2){scale = 2;}
        // We assume that the modulus is larger than the order i.e. order < modulus. Moreover restrict to the case where order-1 \neq jb^i for j \in 0,...., b-1 (which is a very mild condition - finding such a order would actually be ni>

    var g[(b-1)*k][3];
    g[0] = multiples_array[0][0];
    for (var i = 0; i < k; i++) {
        for (var bb = 1; bb < b; bb++) {
            if ((bb != b-1) || (i != k-1)) {
                g[(b-1)*i + bb] = addscalar_sw(g[(b-1)*i], g[(b-1)*i + bb - 1], swa, swb);
            }
        }
    }
    var h[3]; // Save g^b
    h = g[scale*(b-1)]; // g^b
    // g^(-(k-2)*b-shift)
    var f[3]=h;
    for (var i = 0; i<k-3;i++){
        f = addscalar_sw(f, h, swa, swb); // fast exp. should be faster
    } // g^(b*(k-2))
    f = addscalar_sw(f, g[shift-1], swa, swb);// g^(b*(k-2)+shift)
    f[1]=-f[1]; // g^(-b*(k-2)-shift)

   
    // Start multiplying with terms jb^1
    var ii = b-1;
    sumin = 0;
    sum = 0;
    var suminf = 0; // for the infinity case
    for (var bb = 1; bb < b; bb++) { // 1-term omitted
        g[ii] = addscalar_sw(g[ii],g[shift-1], swa, swb);// Add g^shift to all terms jb^l for l=1
        sumin += s[b+bb] * g[ii][0]; // g^(b+shift)*s[b]+g^(2b+shift)s[b+1]+
        sum += s[b+bb] * g[ii][1];
        suminf += s[b+bb]; // s[b]+s[b+1]+...
        ii++;
    }
    sumin += (1-suminf) * g[shift-1][0]; // (1-\sum s[i])g^(shift)
    sum +=  (1-suminf) * g[shift-1][1]; // In sum: g^(shift) (sum^(b-1)_{i=0} s[i]g^(ib), ii = 2(b-1)
    // Only use affine coordinates as long as possible


    signal intermediateResults[k-1][2];
    intermediateResults[0][0] <== sumin;
    intermediateResults[0][1] <== sum;
    component adders[k-2];
    for (var i = 2; i < k; i++) {
        adders[i-2] = group_law_sw();
        adders[i-2].P <== intermediateResults[i-2];
        sumin = 0;
        sum = 0;
        suminf = 0;
        for (var bb = 1; bb < b; bb++) {
	    g[ii] = addscalar_sw(g[ii],h, swa, swb);// Add constant to all terms jb^l for l>1
            sumin += s[b*i + bb] * g[ii][0]; // g^(j*b^(2+1))s[bi+j]
            sum += s[b*i + bb] * g[ii][1];
            suminf += s[b*i + bb];
            ii++;
        }
        adders[i-2].Q[0] <== sumin+(1-suminf)*h[0]; // g^b sum s[bi+j]g^(jb^2)
        adders[i-2].Q[1] <== sum+(1-suminf)*h[1];
        intermediateResults[i-1] <== adders[i-2].out;
    }
    // k-2 set - g^(b*(k-2)+shift) \sum_i=1\sum_j=0 s[bi+j]*g^(jb^i)

    // Add final (first component).
    sumin = 0;
    sum = 0;
    suminf = 0;
    for (var bb = 0; bb < b-1; bb++) {
	g[bb] = addscalar_sw(g[bb],f, swa, swb);
        sumin += s[bb+1] * g[bb][0];
        sum += s[bb+1] * g[bb][1];
        suminf += s[bb+1];
        ii++;
    }

    component add;
    add = group_law_without_infinity_cases(swa, swb);
    add.P.x <== intermediateResults[k-2][0];
    add.P.y <== intermediateResults[k-2][1];
    add.Q.x <== sumin+(1-suminf)*f[0];
    add.Q.y <== sum+(1-suminf)*f[1];
    add.P.notInfty <== 1;
    add.Q.notInfty <== 1;
    out.x <== add.out.x;
    out.y <== add.out.y;
    out.notInfty <== add.out.notInfty;
}

// component main = chord_rule();
// component main = tangent_rule(1, 2);
// component main = double(1, 2);
// component main = IsZero();
// component main = group_law_without_infinity_cases(12345, 23456);
// component main = group_law(12345, 123456);
