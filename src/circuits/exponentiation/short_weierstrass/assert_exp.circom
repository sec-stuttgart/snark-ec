pragma circom 2.2.1;

include "../../curves/shortWeierstrass.circom";
include "../../curves/affinePoint.circom";


/**
* Asserts an exponentiation over a Short Weierstrass curve.
*/
template Assert_exp(base, digits, SW_a, SW_b, powers_of_g, assert_indices) {
    input signal v_indices[digits][base]; // exponent
    input signal v;

    // Test
    input AffinePoint() res;

    if(assert_indices == 1) {
        component assert_indices_comp;
        assert_indices_comp = assert_base_indices(base, digits);
        assert_indices_comp.in <== v;
        assert_indices_comp.in_indices <== v_indices;
    }

    component scalarMul = scalar_mul(SW_a, SW_b, base, digits, powers_of_g);
    scalarMul.m <== v_indices;
    res === scalarMul.out;

    // log("Computed gv: (", gv.x, ", ", gv.y, ", ", gv.notInfty, ")");
    // log("Computed pkr: (", pkr.x, ", ", pkr.y, ", ", pkr.notInfty, ")");
}