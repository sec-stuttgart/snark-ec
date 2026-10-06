pragma circom  2.2.1;

include "../../utilities/listGates.circom";

/**
* Computes the n_best candidates receiving the most votes.
* (May be more than n_best candidates if there is a tie at the n_best-th position.)
*/
template Evaluate_election(n_cand, bits, n_best) {
    input signal tally[n_cand];
    input signal test_out[n_cand];

    output signal out[n_cand];

    component bestMIndicator = computeHighestMEntries(n_cand, bits, n_best);

    bestMIndicator.tally <== tally;
    out <== bestMIndicator.out;

    out === test_out;
}