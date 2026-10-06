pragma circom 2.2.1;

include "../../utilities/asserts.circom";

/**
* Asserts that in a ballot with n_votes entries, each entry is 0 or 1, and all 1-votes are assigned successively.
* A ballot consisting of only zeros is considered valid.
*/
template Line_vote_voting(n_votes) {
    input signal ballot[n_votes];

    component assertBits[n_votes];
    component assertLine = assertBit();

    assertBits[0] = assertBit();
    assertBits[0].in <== ballot[0];

    signal indicator[n_votes];
    indicator[0] <== ballot[0];
    signal tmp[n_votes];


    for(var i = 1; i < n_votes; i++) {
        assertBits[i] = assertBit();
        assertBits[i].in <== ballot[i];

        tmp[i] <== ballot[i] - ballot[i-1];
        indicator[i] <== indicator[i-1] + tmp[i] * ballot[i]; // 1 if there is a change from 0 to 1 from ballot[i-1] to ballot[i], 0 otherwise
    }

    assertLine.in <== indicator[n_votes-1];
}
