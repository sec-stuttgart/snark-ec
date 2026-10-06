pragma circom  2.2.1;

include "../../../../libs/node_modules/circomlib/circuits/comparators.circom";
include "../../../../libs/node_modules/circomlib/circuits/gates.circom";

/**
* Computes n!.
*/
function fact(n) {
    if (n < 0) {
        log("WARNING: Calling factorial for number <= 0");
        return 0; // Default for invalid input
    }
    var res = 1;
    for(var i = 1; i <=n; i++) {
        res *= i;
    }
    return res;
}

/**
* Compute the binomial coefficient (n!)/(k!*(n-k)!).
*/
function binCoeff(n,k) {
    return fact(n)\(fact(k)*fact(n-k));
}

/**
* Computed the number of possible (partial) rankings of n_cand many options.
*/
function numRankingsWithPartialRankings(n_cand) {
    var sum = 0;
    for (var k = 0; k <= n_cand; k++) {
        sum += binCoeff(n_cand,k) * fact(k); // Number of possible subsets of size k multiplied with number of possible orderings of these subsets.
    }
    return sum;
}

/**
* Computes how often one candidate is ranked first if there are n_cand candidates in total.
*/
function getCandRankedFirstCount(n_cand) {
    var rankedFirstCount = numRankingsWithPartialRankings(n_cand-1); // First candidate is fixed, others can be arbitrarily ordered
    return rankedFirstCount;
}

/**
* Computes the number of votes which rank the given chosen_cand first and that have not been filtered out.
*/
template getVotesCandRankedFirst(n_cand, chosen_cand, getFirstRankedPos) {
    var nRankings = numRankingsWithPartialRankings(n_cand);
    var rankedFirstCount = getCandRankedFirstCount(n_cand);
    // var rankedFirstPositions = getCandRankedFirstPositions(n_cand, chosen_cand);
    input signal tally[nRankings];
    input signal eliminatedRankings[nRankings];
    output signal out;

    signal runningVotesCount[rankedFirstCount + 1];
    runningVotesCount[0] <== 0;

    for(var i = 0; i < rankedFirstCount; i++) {
        var pos = getFirstRankedPos[chosen_cand][i];
        runningVotesCount[i+1] <== runningVotesCount[i] + (1-eliminatedRankings[pos]) * tally[pos];
    }

    out <== runningVotesCount[rankedFirstCount];
}

template removeCandidate(nCand, getCandRemovedPos) {
    var nRankings = numRankingsWithPartialRankings(nCand);
    
    signal input tally[nRankings];
    signal input eliminatedRankings[nRankings];
    signal input candToRemove;
    signal input eliminatedCandidates[nCand];

    signal output modifiedTally[nRankings];
    signal output modifiedEliminatedRankings[nRankings];
    signal output modifiedEliminatedCandidates[nCand];

    component isCandRemoved[nCand];
    
    // Create a 2D signal array to hold the intermediate multiplications
    signal shiftAmount[nCand][nRankings];
    
    // We use a mutable variable to accumulate linear combinations of signals.
    var nextTally[nRankings];
    for(var i = 0; i < nRankings; i++) {
        nextTally[i] = tally[i]; // Start with current tallies (degree-1)
    }

    // Iterate through all POSSIBLE candidates that could be removed
    for(var c = 0; c < nCand; c++) {
        isCandRemoved[c] = IsEqual();
        isCandRemoved[c].in[0] <== candToRemove;
        isCandRemoved[c].in[1] <== c;

        // For every ranking, calculate where it goes if candidate 'c' is removed
        for(var pos = 0; pos < nRankings; pos++) {
            
            // 1. Strictly assign the product to an intermediate signal (Signal * Signal = Signal)
            shiftAmount[c][pos] <== isCandRemoved[c].out * tally[pos];
            
            // var targetPos = getCandRemovedPos(nCand, pos, c);
            var targetPos = getCandRemovedPos[pos][c];
            // log("Start pos.:", pos, "Target pos.:", targetPos);
            
            if (targetPos != pos) {
                // 2. Accumulate the intermediate signals (Linear Addition = Valid)
                nextTally[targetPos] += shiftAmount[c][pos];
                nextTally[pos] -= shiftAmount[c][pos];
            }
        }

        modifiedEliminatedCandidates[c] <== eliminatedCandidates[c] + isCandRemoved[c].out - eliminatedCandidates[c] * isCandRemoved[c].out; // OR
    }

    // Assign the accumulated tallies to the output signals
    for(var pos = 0; pos < nRankings; pos++) {
        // Assigning a linear combination of signals to a signal is perfectly valid
        modifiedTally[pos] <== nextTally[pos];
        
        // Pass the eliminated state through
        modifiedEliminatedRankings[pos] <== eliminatedRankings[pos];
    }
}

// component main = getVotesCandRankedFirst(5, 2);
// component main = removeCandidate(5);