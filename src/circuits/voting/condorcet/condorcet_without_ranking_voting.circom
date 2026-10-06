pragma circom 2.2.1;

include "../../utilities/asserts.circom";
include "../../../../libs/node_modules/circomlib/circuits/gates.circom";

/**
* Checks that a given ballot (as a (n x n)-Matrix) confirms to the condorcet election type.
* Condorcet Election type defined in "zk-SNARKS for Ballot Validity: A Feasibility Study".
*/
template Condorcet_without_ranking_voting(n) {
    input signal ranking[n]; // For compatibility, but is not used here
    input signal ballot[n][n];

    // Assert that all entries are bits
    component assertBitsEntries[n][n];
    for(var i = 0; i < n; i++) {
        for(var j = 0; j < n; j++) {
            assertBitsEntries[i][j] = assertBit();
            assertBitsEntries[i][j].in <== ballot[i][j];
        }
    }

    // Assert that all sums of entries a_ij + a_ji are bits (when i is not equal to j).
    component assertBitsSumEntries[n][n];
    for(var i = 0; i < n; i++) {
        for(var j = i + 1; j < n; j++) {
            assertBitsSumEntries[i][j] = assertBit();
            assertBitsSumEntries[i][j].in <== ballot[i][j] + ballot[j][i];
        }
    }

    // Assert Transitivity:
    // For any distinct i, j, k in [1,n]:
    // 1. If i is ranked better or equal than j and j is ranked better or equal than k, then i is ranked better or equal than k
    // 2. If i is ranked the same as j and j is ranked the same as k then i is ranked the same as k.
    // We can translate these Cases to Matrix entries:
    // 1. If a_ji = 0 and a_kj = 0, then a_ki = 0
    // 2. If a_ji = a_ij = 0 and a_kj = a_jk = 0, then a_ki = a_ik = 0
    // We are using the check matrix approach presented in "zk-SNARKS for Ballot Validity: A Feasibility Study" to assert this property.

    signal checkMatrix[n][n];
    for(var i = 0; i < n; i++) {
        for(var j = 0; j < n; j++) {
            checkMatrix[i][j] <== 1 - ballot[i][j];
        }
    }
    component assertTransitivity[n][n][n];
    for(var i = 0; i < n; i++) {
        for(var j = 0; j < n; j++) {
            for(var k = 0; k < n; k++) {
                if(i != j && j != k && i != k) {
                    assertTransitivity[i][j][k] = MultiAND(3);

                    assertTransitivity[i][j][k].in[0] <== checkMatrix[i][j];
                    assertTransitivity[i][j][k].in[1] <== checkMatrix[j][k];
                    assertTransitivity[i][j][k].in[2] <== 1 - checkMatrix[i][k];

                    assertTransitivity[i][j][k].out === 0;
                }
            }
        }
    }
}