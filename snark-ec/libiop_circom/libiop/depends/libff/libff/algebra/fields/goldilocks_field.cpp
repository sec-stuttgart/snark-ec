#include "goldilocks_field.hpp"

namespace libff {
    
    // The modulus (extern in header)
    bigint<goldilocks_limbs> goldilocks_modulus;
    
    // Initialization function
    void init_goldilocks_field() {
        
        // Set modulus
        goldilocks_modulus = bigint<goldilocks_limbs>("18446744069414584321");
        
        // Initialize the Fp_model static constants
        goldilocks_Fp::Rsquared = bigint<goldilocks_limbs>(4294967295);
        goldilocks_Fp::Rcubed = bigint<goldilocks_limbs>(1);
        goldilocks_Fp::inv = 18446744069414584319;
        goldilocks_Fp::num_bits = 64;
        goldilocks_Fp::euler = bigint<goldilocks_limbs>("9223372034707292160");
        goldilocks_Fp::s = 32;
        goldilocks_Fp::t = bigint<goldilocks_limbs>("4294967295");
        goldilocks_Fp::t_minus_1_over_2 = bigint<goldilocks_limbs>("2147483647");
        goldilocks_Fp::multiplicative_generator = goldilocks_Fp("7");
        goldilocks_Fp::root_of_unity = goldilocks_Fp("1753635133440165772");
        goldilocks_Fp::nqr = goldilocks_Fp("7");
        goldilocks_Fp::nqr_to_t = goldilocks_Fp("1753635133440165772");
    }

    template class Fp_model<goldilocks_limbs, goldilocks_modulus>;

} // namespace libff