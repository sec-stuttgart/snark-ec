pragma circom 2.2.1;

include "pvc_single_vote.circom";
include "../../voting/single/single_vote_voting.circom";

/**
* Asserts that the given PVC commitment correpsonds to the given ballot and that the given ballot is in single choice format
*/ 
template Assert_pvc_single_vote(n_entries, base_rand, digits_rand, num_slots_rand, num_gen_rand, SW_a, SW_b, g_plain, powers_of_pk_rand) {
    input signal v[n_entries]; // Plaintexts
    input signal r_indices[digits_rand][base_rand]; // Randomness

    // Test
    input AffinePoint() test_out;

    component assertSingleVote = Single_vote_voting(n_entries);
    assertSingleVote.ballot <== v;

    component pvc = PVC_SingleVote(n_entries, base_rand, digits_rand, num_slots_rand, num_gen_rand, SW_a, SW_b, g_plain, powers_of_pk_rand);
    pvc.v <== v;
    pvc.r_indices <== r_indices;
    
    // log("Plain: ", v);
    log("Given commitment: (", test_out.x, ", ", test_out.y, ", ", test_out.notInfty, ")");
    log("Computed commitment: (", pvc.out.x, ", ", pvc.out.y, ", ", pvc.out.notInfty, ")");
    
    test_out === pvc.out;
}
