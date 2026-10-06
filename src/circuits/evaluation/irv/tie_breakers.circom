pragma circom 2.2.1;

include "../../../../libs/node_modules/circomlib/circuits/comparators.circom";
include "../../../../libs/node_modules/circomlib/circuits/gates.circom";
include "../../utilities/listGates.circom";
include "irv_aux.circom";

/**
* Find first tie breaker.
* Chooses the first minimum as the candidate to remove.
*/
template findFirstTieBreaker(nCand) {
    signal input minIndicators[nCand];
    signal output candToRemove;

    signal runningCandToRemove[nCand + 1];
    runningCandToRemove[nCand] <== -1;
    component ifElse[nCand];
    for (var cand = nCand - 1; cand >= 0; cand--) {
        ifElse[cand] = ifThenElse();
        ifElse[cand].ifV <== cand;
        ifElse[cand].elseV <== runningCandToRemove[cand + 1];
        ifElse[cand].cond <== minIndicators[cand];
        runningCandToRemove[cand] <== ifElse[cand].out;
    }

    candToRemove <== runningCandToRemove[0];    
}

/**
* NSW tie breaker. 
* Uses vote history from previous rounds to determine best candidate to remove.
*/
template nswTieBreaker(nCand, nRounds, currentRound, bits) {
    // Ensure array dimensions are strictly > 0 because circom compilation is stupid
    var safeLen = currentRound == 0 ? 1 : currentRound;

    signal input minIndicators[nCand];               // Tied candidates from the current round
    signal input votesHistory[safeLen][nCand];  // Tally history across all rounds
    signal input tieBreakerLots[nCand];              // The final public fallback lot
    
    signal output candToRemove;

    // activePool tracks who is still tied at each step of the lookback
    signal activePool[currentRound + 1][nCand];
    
    for (var c = 0; c < nCand; c++) {
        activePool[0][c] <== minIndicators[c];
    }

    component historyMin[safeLen];
    
    // Check backwards from round (currentRound - 1) down to 0
    for (var i = 0; i < currentRound; i++) {
        var histIdx = currentRound - 1 - i;
        
        historyMin[i] = computeMinimumIndicatorAtIdx(nCand, bits);
        historyMin[i].in <== votesHistory[histIdx];
        historyMin[i].idx <== activePool[i];
        activePool[i + 1] <== historyMin[i].out; // The output becomes the active pool for the next historical check        
    }

    // --- Final Fallback: Public Lots ---
    // If candidates are tied across ALL historical rounds, the lot decides.
    component lotMin = computeMinimumIndicatorAtIdx(nCand, bits);
    lotMin.in <== tieBreakerLots;
    // The input pool is whatever survived the history checks
    lotMin.idx <== activePool[currentRound];

    // Assuming the candidate with the LOWEST lot value is eliminated
    var tmpCandToRemove = 0;
    for (var i = 0; i < nCand; i++){
        tmpCandToRemove += lotMin.out[i] * i;
    }
    candToRemove <== tmpCandToRemove;
}