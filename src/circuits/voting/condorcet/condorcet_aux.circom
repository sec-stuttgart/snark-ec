pragma circom 2.2.1;

include "../../utilities/branching.circom";
include "../../../../libs/node_modules/circomlib/circuits/comparators.circom";

/**
* Computes the corresponding Condorcet ballot to the ranking. (Since the values on the diagonal have no function, we assume, that those are zero.)
* maxValue is the maximal Value any entry in the ranking should have.
*/
template computeCondorcetBallot(n, max_value_bits) {
    input signal ranking[n];

    output signal out[n][n]; // ballot

    component rankedWorse[n][n];
    component rankedTheSame[n][n];
    component computeEntryIJ[n][n];
    component computeEntryJI[n][n];
    signal tmp[n][n];

    var test = numBits(n);

    for(var i = 0; i < n; i++) {
        for(var j = i; j < n; j++) {
            if(j == i) {
                out[i][j] <== 0;
            } else{
                rankedWorse[i][j] = GreaterThan(max_value_bits); //r_i > r_j implies that i is ranked worse than j.
                rankedTheSame[i][j] = IsEqual(); // r_i = r_j implies that i and ja are ranked the same.
                computeEntryIJ[i][j] = switchCase(3);
                computeEntryJI[i][j] = switchCase(3);

                rankedWorse[i][j].in[0] <== ranking[i];
                rankedWorse[i][j].in[1] <== ranking[j];
                rankedTheSame[i][j].in[0] <== ranking[i];
                rankedTheSame[i][j].in[1] <== ranking[j];

                // tmp[i][j] <== 1 - rankedWorse[i][j].out;

                computeEntryIJ[i][j].cond[0] <== rankedWorse[i][j].out;
                computeEntryIJ[i][j].cond[1] <== rankedTheSame[i][j].out;
                // computeEntryIJ[i][j].s[2] <== tmp[i][j] * (1-rankedTheSame[i][j].out);
                computeEntryIJ[i][j].in[0] <== 0; // a_ij = 0 if i is ranked worse than j
                computeEntryIJ[i][j].in[1] <== 0; // a_ij = 0 if i is ranked the same as j
                computeEntryIJ[i][j].in[2] <== 1; // a_ij = 1 if i is ranked better than j
                out[i][j] <== computeEntryIJ[i][j].out;

                computeEntryJI[i][j].cond[0] <== rankedWorse[i][j].out;
                computeEntryJI[i][j].cond[1] <== rankedTheSame[i][j].out;
                // computeEntryJI[i][j].s[2] <== tmp[i][j] * (1-rankedTheSame[i][j].out);
                computeEntryJI[i][j].in[0] <== 1; // a_ji = 1 if i is ranked worse than j
                computeEntryJI[i][j].in[1] <== 0; // a_ji = 0 if i is ranked the same as j
                computeEntryJI[i][j].in[2] <== 0; // a_ji = 0 if i is ranked better than j
                out[j][i] <== computeEntryJI[i][j].out;
            }
        }
    }
}
