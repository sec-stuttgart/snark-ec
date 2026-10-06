pragma circom 2.2.1;

include "../../../../libs/node_modules/circomlib/circuits/comparators.circom";
include "../../../../libs/node_modules/circomlib/circuits/gates.circom";
include "../../utilities/listGates.circom";
include "irv_aux.circom";

/**
* Evaluates an irv election.
*
* n_rounds: The number of rounds to be evaluated (thus, how many choices are eliminated), if the value given geq n_choices or lower than 0 it defaults to n_choices - 1 (-> All choices except 1 are eliminated).
* bits: Number of bits used to represent ranking entries.
*/
template Evaluate_election(n_cand, n_rounds, bits, allRankings, allRemovalMatrices, candidateIndicatorMatrix) {
    var n_choices = getChoicesWithPartialRankings(n_cand);

    if (n_rounds < 0 || n_rounds >= n_cand) {
        n_rounds = n_cand - 1;
    }

    input signal votes[n_choices];
    input signal tieBreakerLots[n_rounds][n_cand];

    output signal eliminatedIdxFinal[n_choices];

    signal eliminatedIdx[n_rounds+1][n_choices];
    for (var i = 0; i < n_choices; i++) {
        eliminatedIdx[0][i] <== 0;
    }

    signal runningVotes[n_rounds + 1][n_choices];
    runningVotes[0] <== votes;
    component evalRound[n_rounds];
    signal leastFirstRanked[n_rounds][n_cand];
    signal firstRankedCount[n_rounds][n_cand];
    signal eliminatedCand[n_rounds + 1][n_cand]; // Candidates that have been eliminated are marked with 1
    for (var i = 0; i < n_cand; i++) {
        eliminatedCand[0][i] <== 0;
    }
    
    component breakTies[n_rounds];
    component collectEliminatedCand[n_rounds];
    component getEliminatedIdx[n_rounds];
    component collectEliminatedIdx[n_rounds];
    component modifyVotes[n_rounds];

    for (var round = 0; round < n_rounds; round++) {
        evalRound[round] = evaluateRound(n_cand, n_choices, allRankings, bits);
        evalRound[round].votes <== runningVotes[round];
        evalRound[round].eliminatedCand <== eliminatedCand[round];
        leastFirstRanked[round] <== evalRound[round].leastFirstRanked;
        firstRankedCount[round] <== evalRound[round].firstRankedCount;

        breakTies[round] = NSWTieBreaker(n_cand, round, bits);
        breakTies[round].leastFirstRanked <== leastFirstRanked[round];
        breakTies[round].tieBreakerLots <== tieBreakerLots[round];
        for (var i = 0; i <= round; i++) {
            breakTies[round].firstRankedCountHistory[i] <== firstRankedCount[i];
        }

        collectEliminatedCand[round] = pairwiseAddVector(n_cand);
        collectEliminatedCand[round].in1 <== eliminatedCand[round];
        collectEliminatedCand[round].in2 <== breakTies[round].candToEliminate;
        eliminatedCand[round + 1] <== collectEliminatedCand[round].out;

        getEliminatedIdx[round] = linCombVectors(n_cand, n_choices);
        getEliminatedIdx[round].in <== candidateIndicatorMatrix;
        getEliminatedIdx[round].scalar <== breakTies[round].candToEliminate;

        collectEliminatedIdx[round] = pairwiseAddVector(n_choices);
        collectEliminatedIdx[round].in1 <== eliminatedIdx[round];
        collectEliminatedIdx[round].in2 <== getEliminatedIdx[round].out;
        eliminatedIdx[round+1] <== collectEliminatedIdx[round].out;

        modifyVotes[round] = eliminateCandidate(n_cand, n_choices, allRankings, allRemovalMatrices);
        modifyVotes[round].votes <== runningVotes[round];
        modifyVotes[round].candToEliminate <== breakTies[round].candToEliminate;
        runningVotes[round + 1] <== modifyVotes[round].out;
    }

    eliminatedIdxFinal <== eliminatedIdx[n_rounds];
}

component main = evaluateElection(2, 2, 32, 
[[0, 1], [1, 0], [0, -1], [1, -1], [-1, -1]], [[[0, 0, 0, 0, 0], [0, 0, 0, 0, 0], [0, 0, 0, 0, 0], [1, 1, 0, 1, 0], [0, 0, 1, 0, 1]], [[0, 0, 0, 0, 0], [0, 0, 0, 0, 0], [1, 1, 1, 0, 0], [0, 0, 0, 0, 0], [0, 0, 0, 1, 1]]], [[1, 1, 1, 0, 0], [1, 1, 0, 1, 0]]

);