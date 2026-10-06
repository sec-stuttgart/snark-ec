pragma circom  2.2.1;

include "../../utilities/listGates.circom";

/**
* Computes the candidates receiving at least threshold many votes.
*/
template Evaluate_election(n_cand, bits, threshold) {
    input signal tally[n_cand];
    input signal test_out[n_cand];

    output signal out[n_cand];

    component thresholdIndicator = computeThresholdIndicator(n_cand, bits);

    thresholdIndicator.tally <== tally;
    thresholdIndicator.threshold <== threshold;
    out <== thresholdIndicator.indices;

    out === test_out;
}