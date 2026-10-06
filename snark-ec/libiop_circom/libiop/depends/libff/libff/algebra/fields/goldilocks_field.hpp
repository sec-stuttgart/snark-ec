#ifndef GOLDILOCKS_FIELD_HPP_
#define GOLDILOCKS_FIELD_HPP_

#include <libff/algebra/fields/prime_base/fp.hpp>
#include <libff/algebra/field_utils/bigint.hpp>

namespace libff {
    constexpr size_t goldilocks_limbs = 2;
    extern bigint<goldilocks_limbs> goldilocks_modulus;
    typedef Fp_model<goldilocks_limbs, goldilocks_modulus> goldilocks_Fp;
    
    // Initialization
    void init_goldilocks_field();
} // namespace libff

#endif // GOLDILOCKS_FIELD_HPP_