pragma circom 2.2.1;

include "../../utilities/asserts.circom";

/**
* Checks that a given ballot conforms to the Majority Judgement Election type.
* n_cand is the number of Candidates and n_grades is the number of grades.
* For each candidate (rows in the ballot matrix) exactly one of the grades should be set (entry is 1) and the others should be 0.
*/
template Majority_judgement_voting(n_cand, n_grades, n_cand_times_n_grades) {
    input signal linearized_ballot[n_cand_times_n_grades];

    signal ballot[n_cand][n_grades];

    for (var i = 0; i < n_cand; i++) {
        for (var j = 0; j < n_grades; j++) {
            ballot[i][j] <== linearized_ballot[i*n_grades + j];
            // log("Tally (", i, ", ", j, "): ", tally[i][j]);
        }
    }

    component assertBit[n_cand][n_grades];

    for(var i = 0; i < n_cand; i++) {
        var sum = 0;
        for(var j = 0; j < n_grades; j++) {
            assertBit[i][j] = assertBit();
            assertBit[i][j].in <== ballot[i][j];
            sum += ballot[i][j];
        }
        sum === 1;
    }
}
