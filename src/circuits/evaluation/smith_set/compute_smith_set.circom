pragma circom  2.2.1;

include "../../../../libs/node_modules/circomlib/circuits/comparators.circom";
include "../../../../libs/node_modules/circomlib/circuits/gates.circom";
include "../../utilities/listGates.circom";

/**
* Compute the Smith Set for the given tally. The Smith Set is the smallest set of elements from the tally such that every element in the set is higher than every element outside of the set.
* The output is an index list indicating whether an element is in the Smith Set or not. tally[i][j] = m, iff m voters prefer candidate i over candidate j.
* bits is the maximum number of bits needed to represent an entry in tally.
* 
* O(n^3) constraints
*/ 
template Compute_smith_set(n, n_squared, bits) {
    input signal linear_tally[n_squared];
    input signal test_out[n];
    output signal out[n];

    signal tally[n][n];

    for (var i = 0; i < n; i++) {
        for (var j = 0; j < n; j++) {
            tally[i][j] <== linear_tally[i*n + j];
            log("Tally (", i, ", ", j, "): ", tally[i][j]);
        }
    }

    signal isGreater[n][n]; // isGreater[i][j] = 1, iff tally[i][j] > tally[j][i] (More Voters prefer i over j than j over i)
    signal wonMatches[n]; // wonMatches[i] = m, iff there are m positions j, for which isGreater[i][j] = 1.
    component comp[n][n]; 
    for (var i = 0; i < n; i++){
        var winCount = 0;
        for (var j = 0; j < n; j++){
            if (i != j) {
                comp[i][j] = GreaterThan(bits);
                comp[i][j].in[0] <== tally[i][j];
                comp[i][j].in[1] <== tally[j][i];
                isGreater[i][j] <== comp[i][j].out;
                winCount += isGreater[i][j];
            }
        }
        wonMatches[i] <== winCount;
    }
    signal mostWonMatches[n];
    component maxima = computeMaximumIndicator(n, bits);
    maxima.tally <== wonMatches;
    signal runningSmithSet[n][n];
    runningSmithSet[0] <== maxima.indices;
    component isZero[n][n];
    component and[n][n][n];
    for (var i = 1; i < n; i++){
        for (var j = 0; j < n; j++) {
            var smithIndSum = runningSmithSet[i-1][j]; // If j is already in the smith set it should remain there
            for (var k = 0; k < n; k++) {
                if (k != j) {
                    and[i][j][k] = AND();
                    and[i][j][k].a <== isGreater[j][k]; // j wins over k
                    and[i][j][k].b <== runningSmithSet[i-1][k]; // k is in smith set
                    smithIndSum += and[i][j][k].out; // --> j should be in the smith set
                }
            }
            isZero[i][j] = IsZero();
            isZero[i][j].in <== smithIndSum;
            runningSmithSet[i][j] <== 1 - isZero[i][j].out;
        }
    }

    out <== runningSmithSet[n-1];
    log("Smith Set: [");
    for(var i = 0; i < n-1; i++) {
        log(out[i], ", ");
    }
    log(out[n-1], "]");


    out === test_out;
}

// component main = Compute_smith_set(10, 32);