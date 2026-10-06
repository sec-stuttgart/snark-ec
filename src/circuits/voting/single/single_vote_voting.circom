pragma circom 2.2.1;

include "../../utilities/asserts.circom";

/**
* Assert that in a ballot with nVotes votes, each vote is 0 or one and that exactly one vote is one.
*/
template Single_vote_voting(n_votes) {
    input signal ballot[n_votes];

    component assertBit[n_votes];
    component assertSumBit = assertBit();

    var sum = 0;

    for(var i = 0; i < n_votes; i++) {
        assertBit[i] = assertBit();
        assertBit[i].in <== ballot[i];
        sum += ballot[i];
    }

    assertSumBit.in <== sum;
}
