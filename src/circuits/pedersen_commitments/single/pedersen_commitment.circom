pragma circom 2.2.1;

include "../../curves/shortWeierstrass.circom";
include "../../curves/affinePoint.circom";

/**
* Computes a pederrsen commitment over a Short Weierstrass curve.
* 
* digits_rand and digits_plain are the number of digits r and v can have at most.
*/
template PedersenCommitment(base_plain, digits_plain, base_rand, digits_rand, SW_a, SW_b, powers_of_g_plain, powers_of_pk_rand) {
    input signal v_indices[digits_plain][base_plain]; // Plaintext
    input signal r_indices[digits_rand][base_rand]; // Randomness

    output AffinePoint() gv_pkr; // g^v*pk^r

    component scalarMul_gv = scalar_mul(SW_a, SW_b, base_plain, digits_plain, powers_of_g_plain);
    scalarMul_gv.m <== v_indices;
    AffinePoint() gv <== scalarMul_gv.out; // g^v

    component scalarMul_pkr = scalar_mul(SW_a, SW_b, base_rand, digits_rand, powers_of_pk_rand);
    scalarMul_pkr.m <== r_indices;
    AffinePoint() pkr <== scalarMul_pkr.out; // pk^r

    component add_gv_pkr = group_law(SW_a, SW_b);
    add_gv_pkr.P <== gv;
    add_gv_pkr.Q <== pkr;
    gv_pkr <== add_gv_pkr.out;

    // log("Computed gv: (", gv.x, ", ", gv.y, ", ", gv.notInfty, ")");
    // log("Computed pkr: (", pkr.x, ", ", pkr.y, ", ", pkr.notInfty, ")");
}