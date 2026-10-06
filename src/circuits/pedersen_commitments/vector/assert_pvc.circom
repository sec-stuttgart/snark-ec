pragma circom  2.2.1;

include "../../curves/shortWeierstrass.circom";
include "../../utilities/asserts.circom";
include "pvc.circom";

template Assert_pvc(n_entries, base_plain, digits_plain, base_rand, digits_rand, num_slots_plain, num_gen_plain, SW_a, SW_b, powers_of_g_plain, powers_of_pk_rand, rand_base_check, with_packing) {
    input signal v[n_entries];
    input signal v_indices[n_entries][digits_plain][base_plain]; // Plaintext
    input signal r_indices[digits_rand][base_rand]; // Randomness
    input signal r;

    // log("Plain value: ", v);

    // Test
    input AffinePoint() test_out;

    if (rand_base_check == 1) {
        component rand_base_assertion = assert_base_indices(base_rand, digits_rand);
        rand_base_assertion.in <== r;
        rand_base_assertion.in_indices <== r_indices;
    }

    component plain_base_assertion[n_entries];
    for(var i = 0; i < n_entries; i++) {
        plain_base_assertion[i] = assert_base_indices(base_plain, digits_plain);
        plain_base_assertion[i].in <== v[i];
        plain_base_assertion[i].in_indices <== v_indices[i];
    }

    component pvc;

    pvc = PedersenVectorCommitment(n_entries, base_plain, digits_plain, base_rand, digits_rand, num_slots_plain, num_gen_plain, SW_a, SW_b, powers_of_g_plain, powers_of_pk_rand, with_packing);
    pvc.v_indices <== v_indices;
    pvc.r_indices <== r_indices;

    // log("Plain: ", v);
    log("Given commitment: (", test_out.x, ", ", test_out.y, ", ", test_out.notInfty, ")");
    log("Computed commitment: (", pvc.out.x, ", ", pvc.out.y, ", ", pvc.out.notInfty, ")");

    test_out === pvc.out;
}

