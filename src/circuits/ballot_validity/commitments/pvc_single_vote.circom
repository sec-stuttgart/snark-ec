pragma circom 2.2.1;

include "../../curves/shortWeierstrass.circom";
include "../../curves/affinePoint.circom";

function fastexp(base, exp, SW_a, SW_b) {
    var result[3];
    result[0] = 0;
    result[1] = 0;
    result[2] = 0;

    while (exp > 0) {
        if (exp & 1) {
            result = addscalar_sw(result, base, SW_a, SW_b);
        }
        base = addscalar_sw(base, base, SW_a, SW_b);
        exp >>= 1;
    }

    return result;
}

/**
* Computes a pedersen vector commitment over a Short Weierstrass curve.
* The input vector v must conform to the single vote format for this circuit to work.
*/
template PVC_SingleVote(
    n_entries,
    base_rand,
    digits_rand,
    num_slots,
    num_gen,
    SW_a,
    SW_b,
    g_plain,
    powers_of_pk_rand
) {
    input signal v[n_entries];                    // Plaintexts
    input signal r_indices[digits_rand][base_rand]; // Randomness

    output AffinePoint() out;                     // g^v1*g^v2*...*g^vn*pk^r

    component scalarMul_pkr = scalar_mul(
        SW_a,
        SW_b,
        base_rand,
        digits_rand,
        powers_of_pk_rand
    );
    scalarMul_pkr.m <== r_indices;
    AffinePoint() pkr <== scalarMul_pkr.out;      // pk^r

    var sum[3];

    sum = [0, 0, 0];

    var slot = base_rand ** digits_rand;
    var h[num_slots][3];

    for (var j = 0; j < num_gen; j++) {
        h[0] = g_plain[j];
        for (var i = 1; i < num_slots; i++) {
            h[i] = fastexp(h[i - 1], slot, SW_a, SW_b);
        }
        for (var i = 0; i < num_slots; i++) {
            for (var k = 0; k < 3; k++) {
                if (j*num_slots + i < n_entries){
                    sum[k] += v[j*num_slots + i] * h[i][k];
                }
            }
        }
    }

    component add_gv = group_law(SW_a, SW_b);

    add_gv.P.x <== sum[0];
    add_gv.P.y <== sum[1];
    add_gv.P.notInfty <== sum[2];

    add_gv.Q <== pkr;

    out <== add_gv.out;

}
