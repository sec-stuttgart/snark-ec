#include <iostream>
#include <libiop/relations/r1cs.hpp>
#include "r1cs_json_parser.hpp"
#include "witness_json_parser.hpp"
#include <chrono>



// Field
#ifdef USE_BN254

#include <libff/algebra/curves/alt_bn128/alt_bn128_fields.hpp>
#include <libff/algebra/curves/alt_bn128/alt_bn128_pp.hpp>

using FieldT = libff::alt_bn128_Fr;

#elif defined(USE_P384)

#include <libff/algebra/fields/p384.hpp>

using FieldT = libff::p384_Fp;

#else

#include <libff/algebra/fields/goldilocks_field.hpp>
#include <libff/algebra/fields/goldilocks_pp.hpp>

using FieldT = libff::goldilocks_Fp;

#endif

// SNARK
#include <libiop/snark/ligero_snark.hpp>
#include <libiop/bcs/bcs_common.hpp>
#include <libiop/bcs/common_bcs_parameters.hpp>

int main(int argc, char** argv)
{
    #ifdef USE_BN254
    libff::alt_bn128_pp::init_public_params();
    #elif defined(USE_P384)
    libff::init_p384_field();
    #else
    libff::goldilocks_pp::init_public_params();
    #endif

    if (argc < 4) {
        std::cerr << "Usage: ./ligero constraints.json compile.log witness.json\n";
        return 1;
    }

    
    using hash_type = libiop::binary_hash_digest; // default hash
    std::cout << "Parsing R1CS...\n";
    // Parse R1CS log for sizes
    auto meta = parse_r1cs_log(argv[2]);

    libiop::r1cs_constraint_system<FieldT> r1cs;
    r1cs.constraints_.reserve(meta.num_constraints);

    parse_r1cs_json<FieldT>(
        argv[1],
        r1cs,
        meta.primary_input_size,
        meta.auxiliary_input_size
    );
    std::cout << "R1CS parsed.\n";
    std::cout << "* Constraints: " << r1cs.num_constraints()
              << " (expected " << meta.num_constraints << ")\n";
    std::cout << "* Variables: " << r1cs.num_variables()
              << " (expected " << meta.num_variables << ")\n\n";

    std::cout << "Parsing Witness...\n";
    // Parse witness
    libiop::r1cs_primary_input<FieldT> primary_input;
    libiop::r1cs_auxiliary_input<FieldT> auxiliary_input;

    parse_witness_json<FieldT>(
        argv[3],
        meta.primary_input_size,
        meta.auxiliary_input_size,
        primary_input,
        auxiliary_input
    );

    bool satisfied = r1cs.is_satisfied(primary_input, auxiliary_input);

    std::cout << "R1CS satisfied: " << satisfied << "\n\n";


    if (!satisfied) {
        std::cerr << "Cannot prove: inputs do not satisfy the R1CS!\n";
        return 1;
    }

    // -------------------------
    // Set up Ligero parameters
    // -------------------------
    libiop::ligero_snark_parameters<FieldT, hash_type> parameters;
    parameters.security_level_ = 128; // 128-bit security
    parameters.LDT_reducer_soundness_type_ =  libiop::LDT_reducer_soundness_type::optimistic_heuristic;
    parameters.height_width_ratio_ = 0.1f;
    parameters.RS_extra_dimensions_ = 3; //perhaps 2 is better
    parameters.make_zk_ = true; // set true if you want zero-knowledge
    parameters.domain_type_ = libiop::multiplicative_coset_type;
    parameters.bcs_params_ = libiop::default_bcs_params<FieldT, hash_type>(
        libiop::blake2b_type, 128, 10 // hash type, security, log_n_min
    );

    parameters.describe();

    std::cout << "\n";
    std::cout << "Starting proof generation...\n";
    auto start_prove = std::chrono::high_resolution_clock::now();

    // -------------------------
    // Produce the Ligero proof
    // -------------------------
    libiop::ligero_snark_argument<FieldT, hash_type> proof =
        libiop::ligero_snark_prover<FieldT, hash_type>(
            r1cs,
            primary_input,
            auxiliary_input,
            parameters
        );
    auto end_prove = std::chrono::high_resolution_clock::now();

    std::chrono::duration<double> prove_duration = end_prove - start_prove;
    std::cout << "\n";
    std::cout << "Proof computed!\n";
    std::cout << "Proof size (bytes, total): " << proof.size_in_bytes() << "\n";
    std::cout << "Proof generation time (seconds): " << prove_duration.count() << "\n\n";
    
    std::cout << "Starting proof verification..." << prove_duration.count() << "\n";
    auto start_verify = std::chrono::high_resolution_clock::now();

    // -------------------------
    // Verify the proof
    // -------------------------
    bool verified = libiop::ligero_snark_verifier<FieldT, hash_type>(
        r1cs,
        primary_input,
        proof,
        parameters
    );
    auto end_verify = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> verify_duration = end_verify - start_verify;
    std::cout << "\n";
    std::cout << "Verification complete!\n";
    std::cout << "Proof verification: " << (verified ? "true" : "false") << "\n";
    std::cout << "Proof verification time (seconds): " << verify_duration.count() << "\n";

    return 0;
}