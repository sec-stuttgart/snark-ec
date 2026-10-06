pragma circom 2.2.1;

include "condorcet_aux.circom";

/**
* Assert that the given ballot corresponds to the given ranking according to the condorcet election type.
* Parameters n_cand, bits_votes are defined the same as in computeCondorcetBallot.
*/
template Condorcet_voting(bits_votes, n_cand, n_cand_squared) {
    input signal ranking[n_cand];
    input signal linearized_ballot[n_cand_squared];
    
    signal ballot[n_cand][n_cand];

    for (var i = 0; i < n_cand; i++) {
        for (var j = 0; j < n_cand; j++) {
            ballot[i][j] <== linearized_ballot[i*n_cand + j];
        }
    }

    component computeBallot = computeCondorcetBallot(n_cand, bits_votes);
    computeBallot.ranking <== ranking;
    signal computedBallot[n_cand][n_cand] <== computeBallot.out;

    for(var i = 0; i < n_cand; i++) {
        for(var j = 0; j < n_cand; j++) {
            ballot[i][j] === computedBallot[i][j];
        }
    }
    
}