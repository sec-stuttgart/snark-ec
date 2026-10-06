pragma circom  2.2.1;

include "../../../../libs/node_modules/circomlib/circuits/comparators.circom";
include "../../../../libs/node_modules/circomlib/circuits/gates.circom";
include "../../utilities/listGates.circom";
include "../../utilities/branching.circom";
include "../../utilities/arithmetic.circom";

/**
* Computes the (singular) winner of a majority judgement election.
*/
template Evaluate_election_full(n_cand, n_grades, n_cand_times_n_grades, bits, n_votes) {
    input signal linear_tally[n_cand_times_n_grades];
    input signal test_out[n_cand];
    output signal out[n_cand]; // out[i]=1, if the candidate at position i won.
    
    signal tally[n_cand][n_grades];

    for (var i = 0; i < n_cand; i++) {
        for (var j = 0; j < n_grades; j++) {
            tally[i][j] <== linear_tally[i*n_grades + j];
            // log("Tally (", i, ", ", j, "): ", tally[i][j]);
        }
    }

    // 1. Calculate Halved Votes
    var n_votes_halved = n_votes\2;

    // 2. Initial Medians
    component get_medians[n_cand];
    signal median_grades[n_cand];
    for (var i = 0; i < n_cand; i++) {
        get_medians[i] = getAggregatedValuesMedian(n_grades, bits);
        get_medians[i].in <== tally[i];
        median_grades[i] <== get_medians[i].out;
    }

    // 3. Best Median
    component get_best_median = minValue(n_cand, bits);
    for (var i = 0; i < n_cand; i++) {
        get_best_median.in[i] <== median_grades[i];
    }
    signal best_median <== get_best_median.out;

    // 4. Initial Winners Indicator
    component eq_med[n_cand];
    // State arrays to hold variables across the loop iterations
    signal ind_winner_st[n_cand + 1][n_cand]; 
    
    for (var i = 0; i < n_cand; i++) {
        eq_med[i] = IsEqual();
        eq_med[i].in[0] <== median_grades[i];
        eq_med[i].in[1] <== best_median;
        ind_winner_st[0][i] <== eq_med[i].out;
    }

    // 5. Initial State Variables
    signal i_plus[n_cand + 1];
    signal i_minus[n_cand + 1];
    i_plus[0] <== 1;
    i_minus[0] <== 1;
    // We don't need 's' as a signal since it's just initialized to 1 and not used directly in the py code prior to sis

    // Generate indicator lists
    component get_ind_better = getListWithUpToIndexSet(n_grades);
    get_ind_better.idx <== best_median - 1;
    signal ind_better_than_median_grade[n_grades] <== get_ind_better.out;

    component get_ind_worse = getListWithStartingFromIndexSet(n_grades);
    get_ind_worse.idx <== best_median + 1;
    signal ind_worse_than_median_grade[n_grades] <== get_ind_worse.out;

    // Initialize round 0 ps, qs, ms_minus, ms_plus
    signal ps[n_cand + 1][n_cand];
    signal qs[n_cand + 1][n_cand];
    signal ms_minus[n_cand + 1][n_cand];
    signal ms_plus[n_cand + 1][n_cand];

    component getInitialPs[n_cand];
    component getInitialQs[n_cand];

    for (var i = 0; i < n_cand; i++) {
        getInitialPs[i] = sumIdxVector(n_grades);
        getInitialQs[i] = sumIdxVector(n_grades);

        getInitialPs[i].in <== tally[i];
        getInitialPs[i].idx <== ind_better_than_median_grade;
        ps[0][i] <== getInitialPs[i].out;
        getInitialQs[i].in <== tally[i];
        getInitialQs[i].idx <== ind_worse_than_median_grade;
        qs[0][i] <== getInitialQs[i].out;

        ms_minus[0][i] <== n_votes_halved - ps[0][i];
        ms_plus[0][i] <== n_votes_halved - qs[0][i];
    }

    // 6. Main Tie-Breaking Loop
    component lt_ms[n_cand][n_cand];
    component if_else_sis[n_cand][n_cand];
    component get_s_max[n_cand];
    component eq_smax_zero[n_cand];
    component eq_sis_smax[n_cand][n_cand];
    // component if_else_ind_winner[n_cand][n_cand];
    component gt_smax[n_cand];
    
    component get_ms_minus_index[n_cand][n_cand];
    component get_ms_plus_index[n_cand][n_cand];

    
    component if_else_ms_plus[n_cand][n_cand];
    component if_else_ms_minus[n_cand][n_cand];
    component if_else_ps[n_cand][n_cand];
    component if_else_qs[n_cand][n_cand];
    component if_else_i_minus[n_cand];
    component if_else_i_plus[n_cand];

    signal sis[n_cand][n_cand];
    signal s_max[n_cand];
    signal ind_s_max_zero[n_cand];
    signal ind_s_max_gt_zero[n_cand];

    for (var round = 0; round < n_cand; round++) {
        
        // Calculate sis
        for (var i = 0; i < n_cand; i++) {
            lt_ms[round][i] = LessThan(bits);
            lt_ms[round][i].in[0] <== ms_minus[round][i];
            lt_ms[round][i].in[1] <== ms_plus[round][i];
            
            if_else_sis[round][i] = ifThenElse();
            if_else_sis[round][i].ifV <== ps[round][i];
            if_else_sis[round][i].elseV <== -qs[round][i];
            if_else_sis[round][i].cond <== lt_ms[round][i].out;
            
            sis[round][i] <== ind_winner_st[round][i] * (if_else_sis[round][i].out + n_votes_halved);
        }

        // Get s_max
        get_s_max[round] = maxValue(n_cand, bits);
        get_s_max[round].in <== sis[round];
        s_max[round] <== get_s_max[round].out;

        // Condition checks
        eq_smax_zero[round] = IsZero();
        eq_smax_zero[round].in <== s_max[round] - n_votes_halved;
        ind_s_max_zero[round] <== eq_smax_zero[round].out;

        gt_smax[round] = GreaterThan(bits);
        gt_smax[round].in[0] <== s_max[round];
        gt_smax[round].in[1] <== n_votes_halved;
        ind_s_max_gt_zero[round] <== gt_smax[round].out;

        // Update winners
        for (var i = 0; i < n_cand; i++) {
            eq_sis_smax[round][i] = IsEqual();
            eq_sis_smax[round][i].in[0] <== sis[round][i];
            eq_sis_smax[round][i].in[1] <== s_max[round];

            // if_then_else(ind, eq(...), ind) -> ind * eq_out + (1 - ind) * ind -> ind * eq_out
            ind_winner_st[round + 1][i] <== ind_winner_st[round][i] * eq_sis_smax[round][i].out;
        }

        // Precompute branch states
        for (var i = 0; i < n_cand; i++) {
            // sgtzero branch logic
            var ms_plus_sgtzero = ms_plus[round][i] - ms_minus[round][i];
            
            get_ms_minus_index[round][i] = getValueAtIdx(n_grades);
            get_ms_minus_index[round][i].in <== tally[i];
            get_ms_minus_index[round][i].idx <== best_median - i_minus[round];
            var ms_minus_sgtzero = get_ms_minus_index[round][i].out;
            
            var ps_sgtzero = ps[round][i] - ms_minus_sgtzero;
            
            // slzero branch logic
            var ms_minus_slzero = ms_minus[round][i] - ms_plus[round][i];
            
            get_ms_plus_index[round][i] = getValueAtIdx(n_grades);
            get_ms_plus_index[round][i].in <== tally[i];
            get_ms_plus_index[round][i].idx <== best_median + i_plus[round];
            var ms_plus_slzero = get_ms_plus_index[round][i].out;
            
            var qs_slzero = qs[round][i] - ms_plus_slzero;

            // Apply multiplexing based on ind_s_max_gt_zero
            var cond_gt = ind_s_max_gt_zero[round];
            
            if_else_ms_plus[round][i] = ifThenElse();
            if_else_ms_plus[round][i].ifV <== ms_plus_sgtzero;
            if_else_ms_plus[round][i].elseV <== ms_plus_slzero;
            if_else_ms_plus[round][i].cond <== cond_gt;
            ms_plus[round + 1][i] <== if_else_ms_plus[round][i].out;

            if_else_ms_minus[round][i] = ifThenElse();
            if_else_ms_minus[round][i].ifV <== ms_minus_sgtzero;
            if_else_ms_minus[round][i].elseV <== ms_minus_slzero;
            if_else_ms_minus[round][i].cond <== cond_gt;
            ms_minus[round + 1][i] <== if_else_ms_minus[round][i].out;

            if_else_ps[round][i] = ifThenElse();
            if_else_ps[round][i].ifV <== ps_sgtzero;
            if_else_ps[round][i].elseV <== ps[round][i];
            if_else_ps[round][i].cond <== cond_gt;
            ps[round + 1][i] <== if_else_ps[round][i].out;

            if_else_qs[round][i] = ifThenElse();
            if_else_qs[round][i].ifV <== qs[round][i];
            if_else_qs[round][i].elseV <== qs_slzero;
            if_else_qs[round][i].cond <== cond_gt;
            qs[round + 1][i] <== if_else_qs[round][i].out;
        }

        // Update i_minus and i_plus
        var cond_gt = ind_s_max_gt_zero[round];
        var i_minus_sgtzero = i_minus[round] + 1;
        var i_plus_sgtzero = i_plus[round] + 1;

        if_else_i_minus[round] = ifThenElse();
        if_else_i_minus[round].ifV <== i_minus_sgtzero;
        if_else_i_minus[round].elseV <== i_minus[round];
        if_else_i_minus[round].cond <== cond_gt;
        i_minus[round + 1] <== if_else_i_minus[round].out;

        if_else_i_plus[round] = ifThenElse();
        if_else_i_plus[round].ifV <== i_plus[round];
        if_else_i_plus[round].elseV <== i_plus_sgtzero;
        if_else_i_plus[round].cond <== cond_gt;
        i_plus[round + 1] <== if_else_i_plus[round].out;
    }

    // Final assignment to output
    out <== ind_winner_st[n_cand];

    log("Result: (out, test)");
    for(var i = 0; i < n_cand; i++) {
        log("(", out[i], ", ", test_out[i], ")");
    }

    out === test_out;
}