pragma circom 2.2.1;

include "../../utilities/listGates.circom";

/**
* Given: A ranking of length n and the points a and b to be given to each candidate for every candidate ranked worse/ equal than the current one.
* The template then computes the according ballot. The maximum value any entry in the ranking can have is n. (Entries that are at most n are enpugh to produce all possible rankings of n candidates.)
*/
template computeBordaTournamentStyleBallot(n, a, b) {
    input signal ranking[n];

    output signal out[n]; // ballot

    component rankedWorse[n];
    component rankedTheSame[n];
    component getAccordingPoints[n];

    signal rankedWorsePoints[n];
    signal rankedTheSamePoints[n];

    for(var i = 0; i < n; i++) {
        rankedWorse[i] = countGreater(n);
        rankedTheSame[i] = countEqual(n);

        rankedWorse[i].in <== ranking;
        rankedWorse[i].test <== ranking[i];

        rankedTheSame[i].in <== ranking;
        rankedTheSame[i].test <== ranking[i];

        rankedWorsePoints[i] <== a * rankedWorse[i].out;
        rankedTheSamePoints[i] <== b * (rankedTheSame[i].out - 1); // (... -1) to exclude the entry at position i

        out[i] <== rankedWorsePoints[i] + rankedTheSamePoints[i];
    }
}