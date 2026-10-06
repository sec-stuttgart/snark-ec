pragma circom 2.2.1;

include "../../../curves/twistedEdwardsCurve.circom";

/**
* Computes an exponential ElGamal ciphertext over a Twisted Edwards curve.
* 
* For given powers of a generator [g^1,g^2,g^4,...,g^{2^{digits_rand-1}}], powers of a public key [pk^1,pk^2,pk^4, ..., pk^{2^{digits_rand-1}}], plaintext v and randomness r, the ciphertext is (g^r, g^v*pk^r)
* 
* digits_rand and digits_plain are the number of digits r and v can have at most.
*/
template Exp_elgamal(base_plain, digits_plain, base_rand, digits_rand, TE_a, TE_d, powers_of_g_plain, powers_of_g_rand, powers_of_pk_rand) {
    input signal v_indices[digits_plain][base_plain]; // Plaintext
    input signal r_indices[digits_rand][base_rand]; // Randomness

    output TwistedEdwardsPoint() gr; // g^r
    output TwistedEdwardsPoint() gv_pkr; // g^v * pk^r

    component scalarMul_gv = twistedEdwardsScalarMulArbitraryBaseFixedPowers(base_plain, digits_plain, TE_a, TE_d, powers_of_g_plain);
    scalarMul_gv.m <== v_indices;
    TwistedEdwardsPoint() gv <== scalarMul_gv.out; // g^v

    component scalarMul_pkr = twistedEdwardsScalarMulArbitraryBaseFixedPowers(base_rand, digits_rand, TE_a, TE_d, powers_of_pk_rand);
    scalarMul_pkr.m <== r_indices;
    TwistedEdwardsPoint() pkr <== scalarMul_pkr.out; // pk^r

    component scalarMul_gr = twistedEdwardsScalarMulArbitraryBaseFixedPowers(base_rand, digits_rand, TE_a, TE_d, powers_of_g_rand);
    scalarMul_gr.m <== r_indices;
    gr <== scalarMul_gr.out;

    component add_gv_pkr = twistedEdwardsGroupLaw(TE_a, TE_d);
    add_gv_pkr.p1 <== gv;
    add_gv_pkr.p2 <== pkr;
    gv_pkr <== add_gv_pkr.out;
}