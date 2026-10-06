#ifndef P384_FIELD_HPP_
#define P384_FIELD_HPP_

#include <libff/algebra/fields/prime_base/fp.hpp>
#include <libff/algebra/field_utils/bigint.hpp>

namespace libff {
    constexpr size_t p384_limbs = 6;
    extern bigint<p384_limbs> p384_modulus;
    typedef Fp_model<p384_limbs, p384_modulus> p384_Fp;

    // Initialization
    void init_p384_field();
} // namespace libff

#endif // P384_FIELD_HPP_
