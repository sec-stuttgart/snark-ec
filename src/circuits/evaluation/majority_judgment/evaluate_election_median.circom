pragma circom  2.2.1;

include "../../../../libs/node_modules/circomlib/circuits/comparators.circom";
include "../../../../libs/node_modules/circomlib/circuits/gates.circom";
include "../../utilities/listGates.circom";

/**
* Computes the median grade for each of the candidates.
*/
template Evaluate_election(n_cand, n_grades, n_cand_times_n_grades, bits) {
    input signal linear_tally[n_cand_times_n_grades];
    input signal test_out[n_cand];

    output signal out[n_cand];

    signal tally[n_cand][n_grades];

    for (var i = 0; i < n_cand; i++) {
        for (var j = 0; j < n_grades; j++) {
            tally[i][j] <== linear_tally[i*n_grades + j];
            // log("Tally (", i, ", ", j, "): ", tally[i][j]);
        }
    }

    component getMedianGrade[n_cand];

    for (var i = 0; i < n_cand; i++) {
        getMedianGrade[i] = getAggregatedValuesMedian(n_grades, bits);
        getMedianGrade[i].in <== tally[i];
        out[i] <== getMedianGrade[i].out;
    }

    /*
    log("Result: (out, test)");
    for(var i = 0; i < n_cand; i++) {
        log("(", out[i], ", ", test_out[i], ")");
    }
    */
    
    out === test_out;
}
