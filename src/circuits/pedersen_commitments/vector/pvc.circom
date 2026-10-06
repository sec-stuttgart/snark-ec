pragma circom 2.2.1;

include "../../curves/shortWeierstrass.circom";
include "../../curves/affinePoint.circom";

/**
* Computes a pederrsen vector commitment over a Short Weierstrass curve.
*
* digits_rand and digits_plain are the number of digits r and v can have at most.
*/
template PedersenVectorCommitment(n_entries, base_plain, digits_plain, base_rand, digits_rand, num_slots_plain, num_gen_plain, SW_a, SW_b, powers_of_g_plain, powers_of_pk_rand, with_packing) {
    input signal v_indices[n_entries][digits_plain][base_plain]; // Plaintexts
    input signal r_indices[digits_rand][base_rand]; // Randomness

    output AffinePoint() out; // g^v1*g^v2*...*g^vn*pk^r

    component scalarMul_pkr = scalar_mul(SW_a, SW_b, base_rand, digits_rand, powers_of_pk_rand);
    scalarMul_pkr.m <== r_indices;

    if (with_packing == 1) {
        var dim = num_slots_plain*digits_plain;
        component scalarMul_gv[num_gen_plain];
        component add_gv[num_gen_plain];
        var v[num_gen_plain][dim][base_plain];
        var res[num_gen_plain];
        for(var k = 0; k < num_gen_plain; k++) {
            for(var i = 0; i < num_slots_plain; i++) {
	        for(var j = 0; j < digits_plain; j++) {
                    if (k*num_slots_plain+i < n_entries){
	    	    v[k][i*digits_plain+j] = v_indices[k*num_slots_plain+i][j];
                    } else {
	    	    for (var l = 0; l < base_plain; l++){
                            v[k][i*digits_plain+j][l] = 0; // SW_Mult needs to allow all zeroe vectors (e.g. if the 0-coeff of each block is computed from the others, not assigned. 
                        }
	    	}
                }
            }
            scalarMul_gv[k] = scalar_mul(SW_a, SW_b, base_plain, dim, powers_of_g_plain[k]);
            scalarMul_gv[k].m <== v[k];
            add_gv[k] = group_law(SW_a, SW_b);
	    add_gv[k].P <== scalarMul_gv[k].out;
            if (k==0){
	        add_gv[k].Q <== scalarMul_pkr.out;
            } else {
                add_gv[k].Q <== add_gv[k-1].out;
            }
        }

        out <== add_gv[num_gen_plain-1].out;
    } else  {
        component scalarMul_gv[n_entries];
        component add[n_entries];
        for(var i = 0; i < n_entries; i++) {
            scalarMul_gv[i] = scalar_mul(SW_a, SW_b, base_plain, digits_plain, powers_of_g_plain[i]);
            scalarMul_gv[i].m <== v_indices[i];

            add[i] = group_law(SW_a, SW_b);
            if(i == 0) {
                add[i].P <== scalarMul_pkr.out;
            } else {
                add[i].P <== add[i-1].out;
            }
            add[i].Q <== scalarMul_gv[i].out;
        }
        out <== add[n_entries-1].out;
    }
}
