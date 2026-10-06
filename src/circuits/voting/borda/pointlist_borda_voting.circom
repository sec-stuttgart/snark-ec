pragma circom 2.2.1;

include "../../utilities/asserts.circom";
include "../../utilities/listGates.circom";
include "../../../../libs/node_modules/circomlib/circuits/comparators.circom";

/**
* Asserts a Borda ballot.
* If n_cand > n_points, we assume, that the pointlist is padded with (n_cand - n_points) zeros.
* ordered_points is the list of points (descending order) and has length m.
*/
template Pointlist_borda_voting(n_cand, n_points, ordered_points) {
    input signal ballot[n_cand];

    signal expectedZeros <== n_cand - n_points;
    component getOccurencesZero = countEqual(n_cand);
    getOccurencesZero.test <== 0;
    getOccurencesZero.in <== ballot;
    signal numZeros <== getOccurencesZero.out;
    numZeros === expectedZeros;

    component getOccurences[n_points];

    for(var i = 0; i < n_points; i++) {
        getOccurences[i] = countEqual(n_cand);
        getOccurences[i].test <== ordered_points[i];
        getOccurences[i].in <== ballot;

        getOccurences[i].out === 1;
    }
}
