pragma circom  2.2.1;

include "../../../curves/twistedEdwardsCurve.circom";
include "../../../utilities/asserts.circom";
include "../../../utilities/bitify.circom";
include "exp_elgamal.circom";

template Assert_exp_elgamal(base_plain, digits_plain, base_rand, digits_rand, TE_a, TE_d, powers_of_g_plain, powers_of_g_rand, powers_of_pk_rand) {
    input signal v;
    input signal v_indices[digits_plain][base_plain]; // Plaintext
    input signal r_indices[digits_rand][base_rand]; // Randomness

    // Test
    input TwistedEdwardsPoint() gr;
    input TwistedEdwardsPoint() gv_pkr;

    component assert_plain_indices;
    assert_plain_indices = assert_base_indices(base_plain, digits_plain);
    assert_plain_indices.in <== v;
    assert_plain_indices.in_indices <== v_indices;

    component exp_elgamal;

    exp_elgamal = Exp_elgamal(base_plain, digits_plain, base_rand, digits_rand, TE_a, TE_d, powers_of_g_plain, powers_of_g_rand, powers_of_pk_rand);
    exp_elgamal.v_indices <== v_indices;
    exp_elgamal.r_indices <== r_indices;

    // log("Given gr: (", gr.x, ", ", gr.y, ")");
    // log("Given gv_pkr: (", gv_pkr.x, ", ", gv_pkr.y, ")");
    // log("Computed gr: (", exp_elgamal.gr.x, ", ", exp_elgamal.gr.y, ")");
    // log("Computed gv_pkr: (", exp_elgamal.gv_pkr.x, ", ", exp_elgamal.gv_pkr.y, ")");
    gr === exp_elgamal.gr;
    gv_pkr === exp_elgamal.gv_pkr;
}