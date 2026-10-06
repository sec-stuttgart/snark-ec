pragma circom 2.2.1;

include "../../utilities/arithmetic.circom";
include "borda_tournament_style_aux.circom";

/**
* Assert that the given ballot corresponds to the given ranking according to the borda tournament style election type.
* Parameters a, b are defined the same as in computeBordaTournamentStyleBallot.
*/
template Borda_tournament_style_voting(n_votes, a, b) {
    input signal ranking[n_votes];
    input signal ballot[n_votes];

    component computeBallot = computeBordaTournamentStyleBallot(n_votes, a, b);
    computeBallot.ranking <== ranking;

    ballot === computeBallot.out;
}
