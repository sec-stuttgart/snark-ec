pragma circom  2.2.1;

include "../../curves/shortWeierstrass.circom";
include "../../utilities/asserts.circom";
include "pedersen_commitment.circom";

template Assert_pedersen_commitment(base_plain, digits_plain, base_rand, digits_rand, SW_a, SW_b, powers_of_g_plain, powers_of_pk_rand) {
    input signal v;
    input signal v_indices[digits_plain][base_plain]; // Plaintext
    input signal r_indices[digits_rand][base_rand]; // Randomness

    // log("Plain value: ", v);

    // Test
    input AffinePoint() gv_pkr;

    component assert_plain_indices;
    assert_plain_indices = assert_base_indices(base_plain, digits_plain);
    assert_plain_indices.in <== v;
    assert_plain_indices.in_indices <== v_indices;

    component pedersen_commitment;

    pedersen_commitment = PedersenCommitment(base_plain, digits_plain, base_rand, digits_rand, SW_a, SW_b, powers_of_g_plain, powers_of_pk_rand);
    pedersen_commitment.v_indices <== v_indices;
    pedersen_commitment.r_indices <== r_indices;

    // log("Plain: ", v);
    // log("Given gv_pkr: (", gv_pkr.x, ", ", gv_pkr.y, ", ", gv_pkr.notInfty, ")");
    // log("Computed gv_pkr: (", pedersen_commitment.gv_pkr.x, ", ", pedersen_commitment.gv_pkr.y, ", ", pedersen_commitment.gv_pkr.notInfty, ")");
    
    gv_pkr === pedersen_commitment.gv_pkr;
}