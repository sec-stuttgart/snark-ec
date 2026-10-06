pragma circom 2.2.1;

include "../../utilities/asserts.circom";

/**
* Assert that in a ballot with n_votes votes, each vote is at most max_votes_cand and that the sum of all votes is at most max_choices.
*/
template Multi_vote_voting(bits_votes, n_votes, max_votes_cand, max_choices) {
    input signal ballot[n_votes];

    var totalBits = bits_votes + numBits(n_votes); // Number of bits required for the sum of all entries at most

    component assertLtEq[n_votes];
    component assertSumLtEq = assertLtEq(totalBits);

    var sum = 0;

    for(var i = 0; i < n_votes; i++) {
        assertLtEq[i] = assertLtEq(bits_votes);
        assertLtEq[i].in <== ballot[i];
        assertLtEq[i].test <== max_votes_cand;
        sum += ballot[i];
    }

    assertSumLtEq.in <== sum;
    assertSumLtEq.test <== max_choices;
}
