pragma circom  2.2.1;

include "../../curves/shortWeierstrass.circom";
include "../../utilities/asserts.circom";
include "../../utilities/bitify.circom";
include "exp_elgamal.circom";

template Assert_exp_elgamal(base_plain, digits_plain, base_rand, digits_rand, SW_a, SW_b, powers_of_g_plain, powers_of_g_rand, powers_of_pk_rand, rand_base_check) {
    input signal v;
    input signal r;
    input signal v_indices[digits_plain][base_plain]; // Plaintext
    input signal r_indices[digits_rand][base_rand]; // Randomness

    // log("Plain value: ", v);

    // Test
    input AffinePoint() gr;
    input AffinePoint() gv_pkr;

    component assert_plain_indices;
    assert_plain_indices = assert_base_indices(base_plain, digits_plain);
    assert_plain_indices.in <== v;
    assert_plain_indices.in_indices <== v_indices;

    if (rand_base_check == 1) {
        component assert_rand_indices;
        assert_rand_indices = assert_base_indices(base_rand, digits_rand);
        assert_rand_indices.in <== r;
        assert_rand_indices.in_indices <== r_indices;
    }

    component exp_elgamal;

    exp_elgamal = Exp_elgamal(base_plain, digits_plain, base_rand, digits_rand, SW_a, SW_b, powers_of_g_plain, powers_of_g_rand, powers_of_pk_rand);
    exp_elgamal.v_indices <== v_indices;
    exp_elgamal.r_indices <== r_indices;

    log("Plain: ", v);
    log("Given gr: (", gr.x, ", ", gr.y, ", ", gr.notInfty, ")");
    log("Given gv_pkr: (", gv_pkr.x, ", ", gv_pkr.y, ", ", gv_pkr.notInfty, ")");
    log("Computed gr: (", exp_elgamal.gr.x, ", ", exp_elgamal.gr.y, ", ", exp_elgamal.gr.notInfty, ")");
    log("Computed gv_pkr: (", exp_elgamal.gv_pkr.x, ", ", exp_elgamal.gv_pkr.y, ", ", exp_elgamal.gv_pkr.notInfty, ")");
    
    gr === exp_elgamal.gr;
    gv_pkr === exp_elgamal.gv_pkr;
}