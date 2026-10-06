pragma circom 2.2.1;
include "../utilities/arithmetic.circom";
include "../utilities/asserts.circom";
include "../../../libs/node_modules/circomlib/circuits/comparators.circom";
include "branching.circom";
include "arithmetic.circom";

/**
* Maximum of the elements in the list.
*/
template maxValue(n, bits) {
    input signal in[n];
    output signal out;
    signal runningMaxValue[n];
    component isGreater[n-1];
    component ifElse[n-1];
    runningMaxValue[0] <== in[0];
    for (var i = 0; i < n-1; i++) {
        isGreater[i] = GreaterThan(bits);
        ifElse[i] = ifThenElse();
        isGreater[i].in[0] <== in[i+1];
        isGreater[i].in[1] <== runningMaxValue[i];
        ifElse[i].ifV <== in[i+1];
        ifElse[i].elseV <== runningMaxValue[i];
        ifElse[i].cond <== isGreater[i].out;
        runningMaxValue[i+1] <== ifElse[i].out;
    }
    out <== runningMaxValue[n-1];
}

/**
* Minimum of the elements in the list.
*/
template minValue(n, bits) {
    input signal in[n];
    output signal out;
    signal runningMinValue[n];
    component isLess[n-1];
    component ifElse[n-1];
    runningMinValue[0] <== in[0];
    for (var i = 0; i < n-1; i++) {
        isLess[i] = LessThan(bits);
        ifElse[i] = ifThenElse();
        isLess[i].in[0] <== in[i+1];
        isLess[i].in[1] <== runningMinValue[i];
        ifElse[i].ifV <== in[i+1];
        ifElse[i].elseV <== runningMinValue[i];
        ifElse[i].cond <== isLess[i].out;
        runningMinValue[i+1] <== ifElse[i].out;
    }
    out <== runningMinValue[n-1];
}

/**
* Maximum of the elements in the input list which are marked by index 1 in idx.
*/
template maxValueAtIdx(n, bits) {
    input signal in[n];
    input signal idx[n];
    output signal out;
    component getMax = maxValue(n, bits);
    for (var i = 0; i < n; i++){
        getMax.in[i] <== in[i] * idx[i];
    }
    out <== getMax.out;
}

/**
* Minimum of the elements in the input list which are marked by index 1 in idx.
*/
template minValueAtIdx(n, bits) {
    input signal in[n];
    input signal idx[n];
    output signal out;
    component ifElse[n];
    component getMin = minValue(n, bits);
    for (var i = 0; i < n; i++){
        ifElse[i] = ifThenElse();
        ifElse[i].ifV <== in[i];
        ifElse[i].elseV <== 2**bits-1; // Max possible value
        ifElse[i].cond <== idx[i];
        getMin.in[i] <== ifElse[i].out;
    }
    out <== getMin.out;
}

/**
* Counts the elements in the array that are greater than test.
* The max allowed value in in is 2^bits - 1.
*/
template countGreaterBits(n, bits) {
    input signal in[n];
    input signal test;
    output signal out;
    component isGreater[n];
    var counter = 0;
    for(var i = 0; i < n; i++) {
        isGreater[i] = GreaterThan(bits);
        isGreater[i].in[0] <== in[i];
        isGreater[i].in[1] <== test;
        counter += isGreater[i].out;
    }
    out <== counter;
}

/**
* Counts the elements in the array that are greater than test.
* The max allowed value in in is n.
*/
template countGreater(n) {
    input signal in[n];
    input signal test;
    output signal out;
    component isGreater[n];
    var counter = 0;
    var maxValueBits = numBits(n);
    for(var i = 0; i < n; i++) {
        isGreater[i] = GreaterThan(maxValueBits);
        isGreater[i].in[0] <== in[i];
        isGreater[i].in[1] <== test;
        counter += isGreater[i].out;
    }
    out <== counter;
}

/**
* Counts the elements in the array that are less than test.
* The max allowed value in in is 2^bits - 1.
*/
template countLessBits(n, bits) {
    input signal in[n];
    input signal test;
    output signal out;
    component isLess[n];
    var counter = 0;
    for(var i = 0; i < n; i++) {
        isLess[i] = LessThan(bits);
        isLess[i].in[0] <== in[i];
        isLess[i].in[1] <== test;
        counter += isLess[i].out;
    }
    out <== counter;
}

/**
* Counts the elements in the array that are less than test.
* The max allowed value in in is n.
*/
template countLess(n) {
    input signal in[n];
    input signal test;
    output signal out;
    component isLess[n];
    var counter = 0;
    var maxValueBits = numBits(n);
    for(var i = 0; i < n; i++) {
        isLess[i] = LessThan(maxValueBits);
        isLess[i].in[0] <== in[i];
        isLess[i].in[1] <== test;
        counter += isLess[i].out;
    }
    out <== counter;
}

/**
* Counts the elements in the array that are equal to test.
*/
template countEqual(n) {
    input signal in[n];
    input signal test;
    output signal out;
    component isEqual[n];
    var counter = 0;
    for(var i = 0; i < n; i++) {
        isEqual[i] = IsEqual();
        isEqual[i].in[0] <== in[i];
        isEqual[i].in[1] <== test;
        counter += isEqual[i].out;
    }
    out <== counter;
}

/**
* Sums up all values in the list.
*/
template sumValues(n) {
    input signal in[n];
    
    output signal out;
    var sum = 0;
    for(var i = 0; i < n; i++) {
        sum += in[i];
    }
    out <== sum;
}

/**
* Chacks whether the test value is in the list.
*/
template isValueInList(n) {
    input signal in[n];
    input signal test;
    output signal out;
    component occurences = countEqual(n);
    component isZero = IsZero();
    occurences.in <== in;
    occurences.test <== test;
    isZero.in <== occurences.out;
    out <== 1 - isZero.out;
}

/**
* Retrieves the value at the given idx.
*/
template getValueAtIdx(n) {
    input signal in[n];
    input signal idx;
    output signal out;

    component idxEqual[n];
    signal tmp[n+1];
    tmp[0] <== 0;
    for (var i = 0; i < n; i++) {
        idxEqual[i] = IsEqual();
        idxEqual[i].in[0] <== idx;
        idxEqual[i].in[1] <== i;
        tmp[i+1] <== tmp[i] + idxEqual[i].out * in[i];
    }
    out <== tmp[n];
}


/**
 * Helper function to compute the median index in pure JavaScript logic.
 * This runs during witness generation only and creates NO constraints.
 */
 /*
function computeMedianIndex(n, list) {
    var vals[n];
    var idxs[n];
    
    // Copy inputs
    for(var i=0; i<n; i++) {
        vals[i] = list[i];
        idxs[i] = i;
    }

    // Simple Bubble Sort (only used for calculation, so efficiency matters less here)
    // We sort pairs (value, original_index)
    for(var i=0; i<n; i++) {
        for(var j=0; j<n-1-i; j++) {
            if(vals[j] > vals[j+1]) {
                // Swap values
                var tmpV = vals[j];
                vals[j] = vals[j+1];
                vals[j+1] = tmpV;
                // Swap indices
                var tmpI = idxs[j];
                idxs[j] = idxs[j+1];
                idxs[j+1] = tmpI;
            }
        }
    }

    // Return the original index of the element at rank n/2
    // If n=5, rank=2. If n=4, rank=2 (the larger of the two medii).
    var medianIdx = idxs[n \ 2];
    var median = list[medianIdx];
    return medianIdx;
}
*/


/**
* Computes the index representing the median of the aggregated values.
* I.e., [2,6,3,2,1,0] means that the value 0 occurs twice in the aggregated values, 1 occurs six times, ... and 5 occurs 0 times.
* Consequently, the median is 1 (<= 7 values are smaller and <= 7 values are larger with there being 14 values in total).
*
* Edge Case: Will return n-1 for an array [0,0,...,0].
*/
template getAggregatedValuesMedian(n, bits) {
    input signal in[n];
    output signal out;

    signal sum;
    signal sum_halve;
    var tmp = 0;
    for (var i = 0; i < n; i++) {
        tmp += in[i];
    }
    sum <== tmp;

    component bit = assertBit();
    sum_halve <-- sum \ 2;
    // log("Sum: ", sum);
    // log("Sum halve: ", sum_halve);
    bit.in <== sum - sum_halve * 2;

    var computedIdx;
    {
        var idx = n-1; // Use last possible idx as default median value if for instance all values are 0.
        var runningTotal = 0;
        for (var i = 0; i < n; i++) {
            runningTotal += in[i];
            if (runningTotal > sum_halve && idx == n-1) { // Use upper median (In case of even sum, use larger grade if tie.)
                idx = i;
            }
        }
        computedIdx = idx;
    }
    out <-- computedIdx;

    var idxBits = numBits(n);
    component less[n];
    component equal[n];
    signal runningTotalLess[n+1];
    runningTotalLess[0] <== 0;
    signal runningTotalEqual[n+1];
    runningTotalEqual[0] <== 0;
    for (var i = 0; i < n; i++) {
        less[i] = LessThan(bits);
        equal[i] = IsEqual();

        less[i].in[0] <== i;
        less[i].in[1] <== out;
        equal[i].in[0] <== i;
        equal[i].in[1] <== out;

        runningTotalLess[i+1] <== runningTotalLess[i] + less[i].out * in[i];
        runningTotalEqual[i+1] <== runningTotalEqual[i] + equal[i].out * in[i];
    }

    signal lessCount <== runningTotalLess[n]; // Total amount of votes with grades smaller than the medium grade.
    signal equalCount <== runningTotalEqual[n]; // Total amount of votes with the median grade.
    signal greaterCount <== sum - lessCount - equalCount;

    component checkLessCount = assertLtEq(bits + idxBits);
    component checkGreaterCount = assertLtEq(bits + idxBits);

    checkLessCount.in <== lessCount;
    checkLessCount.test <== sum_halve;
    checkGreaterCount.in <== greaterCount;
    checkGreaterCount.test <== sum_halve;
}


/**
* Computes the median of a list of values.
*/
template getMedian(n, bits) {
    input signal in[n];
    output signal out;

    // --- 1. HINT GENERATION (Unconstrained) ---
    // Calculate the correct index.
    // (I don't see a way to do this with a helper function, because Circom functions don't recognize constant parameters)
    var computedMedian;
    {
        var vals[n];
        var idxs[n];

        // Copy inputs
        for(var i=0; i<n; i++) {
            vals[i] = in[i];
            idxs[i] = i;
        }

        // Simple Bubble Sort (only used for calculation, so efficiency matters less here)
        // We sort pairs (value, original_index)
        for(var i=0; i<n; i++) {
            for(var j=0; j<n-1-i; j++) {
                if(vals[j] > vals[j+1]) {
                    // Swap values
                    var tmpV = vals[j];
                    vals[j] = vals[j+1];
                    vals[j+1] = tmpV;
                    // Swap indices
                    var tmpI = idxs[j];
                    idxs[j] = idxs[j+1];
                    idxs[j+1] = tmpI;
                }
            }
        }

        // Return the original index of the element at rank n/2
        // If n=5, rank=2. If n=4, rank=2 (the larger of the two medii).
        var medianIdx = idxs[n \ 2];
        var median = in[medianIdx];
        computedMedian = median;
    }

    // Assign the result to the output signal.
    out <-- computedMedian;

    // --- 2. VERIFICATION (Constrained) ---

    // Verify the Rank
    // We need to count how many elements are < medianVal and how many are == medianVal
    component countLess = countLessBits(n, bits);
    component countEqual = countEqual(n);

    signal lessCount;
    signal equalCount;

    countLess.in <== in;
    countLess.test <== out;
    countEqual.in <== in;
    countEqual.test <== out;

    lessCount <== countLess.out;
    equalCount <== countEqual.out;

    // The target Rank K (0-indexed)
    var k = n \ 2; 

    var maxCountBits = numBits(n);

    // Constraint 1: count(Strictly Less) <= k
    component checkLower = LessEqThan(maxCountBits);
    checkLower.in[0] <== lessCount;
    checkLower.in[1] <== k;
    checkLower.out === 1;

    // Constraint 2: count(Strictly Less) + count(Equal) > k
    // This ensures we haven't picked a value that is too small.
    component checkUpper = GreaterThan(maxCountBits);
    checkUpper.in[0] <== lessCount + equalCount;
    checkUpper.in[1] <== k;
    checkUpper.out === 1;
}



/**
* Computes an idx list marking every position with 1 where the original list has the test value.
*/
template idxEqual(n) {
    input signal in[n];
    input signal test;
    output signal out[n];
    component equal[n];
    for (var i = 0; i < n; i++) {
        equal[i] = IsEqual();
        equal[i].in[0] <== in[i];
        equal[i].in[1] <== test;
        out[i] <== equal[i].out;
    }
}

/**
* Multiplies the elements of two lists pairwise.
*/
template pairwiseMultVector(n) {
    signal input in1[n];
    signal input in2[n];
    signal output out[n];
    for (var i = 0; i < n; i++) {
        out[i] <== in1[i] * in2[i];
    }
}

/**
* Adds the elements of two lists pairwise.
*/
template pairwiseAddVector(n) {
    signal input in1[n];
    signal input in2[n];
    signal output out[n];
    for (var i = 0; i < n; i++) {
        out[i] <== in1[i] + in2[i];
    }
}

/**
* Multiplies the elements of two matrices pairwise.
*/
template pairwiseMultMatrix(n, m) {
    signal input in1[n][m];
    signal input in2[n][m];
    signal output out[n][m];
    component vectorMult[n];
    for (var i = 0; i < n; i++) {
        vectorMult[i] = pairwiseMultVector(m);
        vectorMult[i].in1 <== in1[i];
        vectorMult[i].in2 <== in2[i];
        out[i] <== vectorMult[i].out;
    }
}

/**
* Adds the scalar to the input array at the positions specified in idx and leaves the array untouched otherwise.
*/
template scalarAddAtIdx(n) {
    signal input in[n];
    signal input idx[n];
    signal input scalar;
    signal output out[n];
    for (var i = 0; i < n; i++) {
        out[i] <== in[i] + scalar * idx[i];
    }
}

/**
* Sums up all the elements specified by the idx vector in a list.
*/
template sumIdxVector(n) {
    input signal in[n];
    input signal idx[n];
    output signal out;
    signal sum[n+1];
    sum[0] <== 0;
    for (var i = 0; i < n; i++) {
        sum[i+1] <== sum[i] + in[i] * idx[i];
    }
    out <== sum[n];
}

/**
* Creates a list with 1 at the specified position and 0 everywhere else;
*/
template idxPosition(n) {
    signal input in;
    signal output out[n];
    component isEqual[n];
    for (var i = 0; i < n; i++) {
        isEqual[i] = IsEqual();
        isEqual[i].in[0] <== in;
        isEqual[i].in[1] <== i;
        out[i] <== isEqual[i].out;
    }
}

/**
* Multiplies a nxm-matrix with a mxl-matrix.
*/
template matrixMult(n, m, l) {
    signal input in1[n][m];
    signal input in2[m][l];
    signal output out[n][l];
    signal sums[n][l][m+1];
    for (var i = 0; i < n; i++) {
        for (var j = 0; j < l; j++) {
            sums[i][j][0] <== 0;
            for (var k = 0; k < m; k++) {
                sums[i][j][k+1] <== sums[i][j][k] + in1[i][k] * in2[k][j];
            }
            out[i][j] <== sums[i][j][m];
        }
    }
}

/**
* Multiplies a nxm-matrix with a m vector.
*/
template matrixVectorMult(n,m) {
    signal input matrix[n][m];
    signal input vector[m];
    signal output out[n];
    signal sums[n][m+1];
    for (var i = 0; i < n; i++) {
        sums[i][0] <== 0;
        for(var j = 0; j < m; j++) {
            sums[i][j+1] <== sums[i][j] + matrix[i][j] * vector[j];
        }
        out[i] <== sums[i][m];
    }
}

/**
* Multiplies a nxm-matrix with a scalar value.
*/
template scalarMulMatrix(n, m) {
    input signal in[n][m];
    input signal scalar;
    output signal out[n][m];
    for (var i = 0; i < n; i++) {
        for (var j = 0; j < m; j++) {
            out[i][j] <== scalar * in[i][j];
        }
    }
}

/**
* Multiplies a n-vector with a scalar value.
*/
template scalarMulVector(n) {
    input signal in[n];
    input signal scalar;
    output signal out[n];
    for (var i = 0; i < n; i++) {
        out[i] <== scalar * in[i];
    }
}

/**
* Adds two nxm-matrices.
*/
template addMatrices(n,m) {
    signal input in1[n][m];
    signal input in2[n][m];
    signal output out[n][m];
    for(var i = 0; i < n; i++) {
        for(var j = 0; j < m; j++) {
            out[i][j] <== in1[i][j] + in2[i][j];
        }
    }
}

/**
* Creates the linear combination scalar[0]*in[0] + ... + scalar[k-1]*in[k-1].
* Here, in is a list of nxm-matrices.
*/
template linCombMatrices(k, n, m) {
    signal input in[k][n][m];
    signal input scalar[k];
    signal output out[n][m];
    component scalarMul[k];
    component add[k];
    signal sums[k+1][n][m];
    for(var i = 0; i < n; i++) {
        for(var j = 0; j < m; j++) {
            sums[0][i][j] <== 0;
        }
    }
    for(var i = 0; i < k; i++) {
        scalarMul[i] = scalarMulMatrix(n,m);
        scalarMul[i].in <== in[i];
        scalarMul[i].scalar <== scalar[i];
        
        add[i] = addMatrices(n,m);
        add[i].in1 <== sums[i];
        add[i].in2 <== scalarMul[i].out;
        sums[i+1] <== add[i].out;
    }
    out <== sums[k];
}

/**
* Creates the linear combination scalar[0]*in[0] + ... + scalar[k-1]*in[k-1].
* Here, in is a list of nxm-vectors.
*/
template linCombVectors(k, n) {
    signal input in[k][n];
    signal input scalar[k];
    signal output out[n];
    component scalarMul[k];
    component add[k];
    signal sums[k+1][n];
    for(var i = 0; i < n; i++) {
        sums[0][i] <== 0;
    }
    for(var i = 0; i < k; i++) {
        scalarMul[i] = scalarMulVector(n);
        scalarMul[i].in <== in[i];
        scalarMul[i].scalar <== scalar[i];
        
        add[i] = pairwiseAddVector(n);
        add[i].in1 <== sums[i];
        add[i].in2 <== scalarMul[i].out;
        sums[i+1] <== add[i].out;
    }
    out <== sums[k];
}

/**
* Computes an index list with 1 at each position where the tally has a maximum value and 0 at all other positions.
* bits is the maximum number of bits needed to represent an entry in tally.
*/ 
template computeMaximumIndicator(n, bits) {
    input signal tally[n];

    output signal indices[n];

    component maximum = maxValue(n, bits);
    maximum.in <== tally;

    component isEqual[n];

    for (var i = 0; i < n; i++){
        isEqual[i] = IsEqual();
        isEqual[i].in[0] <== maximum.out;
        isEqual[i].in[1] <== tally[i];

        indices[i] <== isEqual[i].out;
    }
}

/**
* Computes an index list with 1 at each position where the input list has a minimum value and 0 at all other positions.
* bits is the maximum number of bits needed to represent an entry in the input.
*/ 
template computeMinimumIndicator(n, bits) {
    input signal in[n];

    output signal out[n];

    component minimum = minValue(n, bits);
    minimum.in <== in;

    component isEqual[n];

    for (var i = 0; i < n; i++){
        isEqual[i] = IsEqual();
        isEqual[i].in[0] <== minimum.out;
        isEqual[i].in[1] <== in[i];

        out[i] <== isEqual[i].out;
    }
}

/**
* Computes an index list with 1 at each position where the subset of the input list marked by an idx of 1 has a minimum value and 0 at all other positions.
* bits is the maximum number of bits needed to represent an entry in the input.
*/ 
template computeMinimumIndicatorAtIdx(n, bits) {
    input signal in[n];
    input signal idx[n];

    output signal out[n];

    component modifyTally[n];
    signal modifiedTally[n];
    component compMinIndicator = computeMinimumIndicator(n, bits);

    for(var i = 0; i < n; i++) {
        modifyTally[i] = ifThenElse();
        modifyTally[i].ifV <== in[i];
        modifyTally[i].elseV <== 2**bits - 1; // Max possible value
        modifyTally[i].cond <== idx[i];
        modifiedTally[i] <== modifyTally[i].out;
    }

    compMinIndicator.in <== modifiedTally;
    out <== compMinIndicator.out;    
}

/**
* Computes an index list with 1 at each position, where the tally value matches or exceeds the threshold and 0 at all other positions.
* bits is the maximum number of bits needed to represent an entry in tally.
*/
template computeThresholdIndicator(n, bits) {
    input signal tally[n];
    input signal threshold;

    output signal indices[n];

    component isGeq[n];

    for (var i = 0; i < n; i++){
        isGeq[i] = GreaterEqThan(bits);
        isGeq[i].in[0] <== tally[i];
        isGeq[i].in[1] <== threshold;

        indices[i] <== isGeq[i].out;
    }
}


/**
* Computes an index list with 1 at the positions of the m highest elements in tally. If there are multiple elements tied for the position of the m-th highest element, the index list will include all of them.
* bits is the maximum number of bits needed to represent an entry in tally.
*/
template computeHighestMEntries(n, bits, m) {
    input signal tally[n];
    
    output signal out[n];

    component countGreater[n];
    component isLess[n];

    for (var i = 0; i < n; i++){
        countGreater[i] = countGreaterBits(n, bits);
        isLess[i] = LessThan(bits);

        countGreater[i].in <== tally;
        countGreater[i].test <== tally[i];

        isLess[i].in[0] <== countGreater[i].out;
        isLess[i].in[1] <== m;

        out[i] <== isLess[i].out;
    }
}

/**
* Returns a list of the given size where every position up to (and including) the given index is set to 1 and all others are set to 0.
*/ 
template getListWithUpToIndexSet(n) {
    signal input idx;
    signal output out[n];

    var bits = numBits(n);

    component isLeq[n];
    for(var i = 0; i < n; i++) {
        isLeq[i] = LessEqThan(bits);
        isLeq[i].in[0] <== i;
        isLeq[i].in[1] <== idx;
        out[i] <== isLeq[i].out;
    }
}

/**
* Returns a list of the given size where every position starting from (and including) the given index is set to 1 and all others are set to 0.
*/ 
template getListWithStartingFromIndexSet(n) {
    signal input idx;
    signal output out[n];

    var bits = numBits(n);

    component isGeq[n];
    for(var i = 0; i < n; i++) {
        isGeq[i] = GreaterEqThan(bits);
        isGeq[i].in[0] <== i;
        isGeq[i].in[1] <== idx;
        out[i] <== isGeq[i].out;
    }
}


// component main = idxPosition(10);
// component main = getAggregatedValuesMedian(10, 32);