pragma circom 2.2.1;

include "../../../../libs/node_modules/circomlib/circuits/comparators.circom";
include "../../../../libs/node_modules/circomlib/circuits/gates.circom";
include "../../utilities/listGates.circom";
include "irv_aux.circom";
include "tie_breakers.circom";

template Evaluate_election_find_first_tie_breaker(nCand, nRounds, bits, nRankings, getCandRemovedPos, getFirstRankedPos) {
    signal input tally[nRankings];
    signal input test_out[nCand];
    
    signal output out[nCand]; // Winner array

    if (nRounds >= nCand || nRounds < 0) {
        nRounds = nCand - 1;
    }

    // State arrays tracking tallies and eliminations across rounds
    signal currentTally[nRounds + 1][nRankings];
    signal eliminatedRankings[nRounds + 1][nRankings];
    signal eliminatedCandidates[nRounds + 1][nCand]; 

    // --- Initialization ---
    currentTally[0] <== tally;
    for (var i = 0; i < nRankings; i++) {
        eliminatedRankings[0][i] <== 0;
    }
    for (var c = 0; c < nCand; c++) {
        eliminatedCandidates[0][c] <== 0;
    }

    // --- Component Declarations ---
    component voteCounters[nRounds][nCand];
    component tieResolvers[nRounds];
    component candidateRemovers[nRounds];
    component getMinFirstRanked[nRounds];
    component computeMinIndicatorList[nRounds];

    // log("Test first ranked counts:");
    // for (var i = 1; i <= nCand; i++) {
    //     var test = getCandRankedFirstCount(i);
    //     log("Candidate count:", i, ", First removed count:", test);
    // }

    // --- Evaluation Rounds ---
    for (var r = 0; r < nRounds; r++) {
        log("====================");
        log("Round", r);
        
        // 1. Count votes for each candidate
        for (var c = 0; c < nCand; c++) {
            voteCounters[r][c] = getVotesCandRankedFirst(nCand, c, getFirstRankedPos);
            voteCounters[r][c].tally <== currentTally[r];
            voteCounters[r][c].eliminatedRankings <== eliminatedRankings[r];
        }

        // 2. Find Minima
        getMinFirstRanked[r] = minValueAtIdx(nCand, bits);
        for (var c = 0; c < nCand; c++) {
            getMinFirstRanked[r].in[c] <== voteCounters[r][c].out;
            getMinFirstRanked[r].idx[c] <== 1 - eliminatedCandidates[r][c];
        }
        computeMinIndicatorList[r] = idxEqual(nCand);
        log("Votes:");
        for (var c = 0; c < nCand; c++) {
            computeMinIndicatorList[r].in[c] <== voteCounters[r][c].out;
            log("Cand", c, ":", voteCounters[r][c].out);
        }
        computeMinIndicatorList[r].test <== getMinFirstRanked[r].out; // Min number of first votes for a candidate
        // log("Least first ranked votes:", getMinFirstRanked[r].out);
        // log("Candidates with minumum votes:");
        // for (var i = 0; i < nCand; i++) {
        //     log(computeMinIndicatorList[r].out[i]);
        // }

        // 3. Resolve Ties
        tieResolvers[r] = findFirstTieBreaker(nCand);
        tieResolvers[r].minIndicators <== computeMinIndicatorList[r].out;
        log("Candidate to remove:", tieResolvers[r].candToRemove);

        // 4. Remove Candidate using your template
        candidateRemovers[r] = removeCandidate(nCand, getCandRemovedPos);
        candidateRemovers[r].candToRemove <== tieResolvers[r].candToRemove;
        candidateRemovers[r].tally <== currentTally[r];
        candidateRemovers[r].eliminatedRankings <== eliminatedRankings[r];
        candidateRemovers[r].eliminatedCandidates <== eliminatedCandidates[r];

        // 5. Pass Modified State to Next Round
        currentTally[r + 1] <== candidateRemovers[r].modifiedTally;
        eliminatedRankings[r + 1] <== candidateRemovers[r].modifiedEliminatedRankings;
        eliminatedCandidates[r + 1] <== candidateRemovers[r].modifiedEliminatedCandidates;
        // log("Total eliminated candidates:");
        // for (var i = 0; i < nCand; i++) {
        //     log(eliminatedCandidates[r + 1][i]);
        // }
    }

    // --- Output Winner ---
    // The winner is the candidate who was never eliminated (has 0 in the tracker)
    for (var c = 0; c < nCand; c++) {
        out[c] <== 1 - eliminatedCandidates[nRounds][c];
    }

    log("Result: (out, test)");
    for(var i = 0; i < nCand; i++) {
        log("(", out[i], ", ", test_out[i], ")");
    }

    out === test_out;
}

// component main = Evaluate_election_find_first_tie_breaker(5, 5, 32);