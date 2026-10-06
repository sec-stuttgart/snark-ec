pragma circom  2.2.1;

include "../../utilities/listGates.circom";

/**
* Computes the candidate receiving the most votes.
*/
template Evaluate_election(n_cand, bits) {
    input signal tally[n_cand];
    input signal test_out[n_cand];

    output signal out[n_cand];

    component maximumIndicator = computeMaximumIndicator(n_cand, bits);

    maximumIndicator.tally <== tally;
    out <== maximumIndicator.indices;

    out === test_out;
}