#ifndef GOLDILOCKS_FIELD_HPP_
#define GOLDILOCKS_FIELD_HPP_

#include <cstdint>
#include <vector>
#include <iostream>
#include <libff/algebra/field_utils/field_utils.hpp>

namespace libff {

class goldilocks_Fp {
public:
    uint64_t v;

    static constexpr uint64_t modulus =
        0xffffffff00000001ULL; // 2^64 - 2^32 + 1
    static constexpr uint64_t mod = modulus;

    static constexpr size_t s = 32;               // 2-adicity
    static constexpr uint64_t t = 0xffffffffULL;  // (p-1)/2^32

    static goldilocks_Fp multiplicative_generator;
    static goldilocks_Fp root_of_unity;
    static goldilocks_Fp nqr;
    static goldilocks_Fp nqr_to_t;

    goldilocks_Fp() : v(0) {}
    goldilocks_Fp(uint64_t x) : v(reduce(x)) {}

    static uint64_t reduce(uint64_t x);
    static uint64_t reduce128(__uint128_t x);

    /* arithmetic */
    goldilocks_Fp& operator+=(const goldilocks_Fp& other);
    goldilocks_Fp& operator-=(const goldilocks_Fp& other);
    goldilocks_Fp& operator*=(const goldilocks_Fp& other);

    goldilocks_Fp operator+(const goldilocks_Fp& other) const;
    goldilocks_Fp operator-(const goldilocks_Fp& other) const;
    goldilocks_Fp operator*(const goldilocks_Fp& other) const;
    goldilocks_Fp operator-() const;

    bool operator==(const goldilocks_Fp& other) const;
    bool operator!=(const goldilocks_Fp& other) const;
    bool is_zero() const;

    goldilocks_Fp squared() const;
    goldilocks_Fp& square();
    goldilocks_Fp inverse() const;
    goldilocks_Fp& invert();

    goldilocks_Fp pow(uint64_t exp) const;
    goldilocks_Fp& operator^=(unsigned long pow);
    goldilocks_Fp operator^(unsigned long pow) const;

    template<std::size_t N>
    goldilocks_Fp& operator^=(const libff::bigint<N> &exp) {
        *this = *this ^ exp;
        return *this;
    }

    template<std::size_t N>
    goldilocks_Fp operator^(const libff::bigint<N> &exp) const {
        goldilocks_Fp result = one();
        goldilocks_Fp b = *this;
        for (std::size_t i = 0; i < N; ++i) {
            uint64_t limb = exp.data[i];
            for (int j = 0; j < 64; ++j) {
                if (limb & 1) result *= b;
                b *= b;
                limb >>= 1;
            }
        }
        return result;
    }


    /* required by libff */
    static goldilocks_Fp zero();
    static goldilocks_Fp one();
    static goldilocks_Fp random_element();
    static constexpr size_t num_limbs = 1;

    static constexpr size_t extension_degree() { return 1; }
    static constexpr size_t ceil_size_in_bits() { return 64; }
    static constexpr size_t floor_size_in_bits() { return 63; }

    std::vector<uint64_t> to_words() const;
    bool from_words(std::vector<uint64_t> words);

    void clear();
    void randomize();

    friend std::ostream& operator<<(std::ostream&, const goldilocks_Fp&);
    friend std::istream& operator>>(std::istream&, goldilocks_Fp&);

    public:

    // Return as bigint (required by libiop)
    libff::bigint<1> as_bigint() const {
    libff::bigint<1> b;
    b.data[0] = static_cast<mp_limb_t>(v);
    return b;
    }

};

template<> struct is_additive<goldilocks_Fp> : std::false_type {};
template<> struct is_multiplicative<goldilocks_Fp> : std::true_type {};

template<std::size_t N>
inline goldilocks_Fp operator^(const goldilocks_Fp &base, const libff::bigint<N> &exp)
{
    goldilocks_Fp result = goldilocks_Fp::one();
    goldilocks_Fp b = base;

    for (std::size_t i = 0; i < N; ++i) {
        uint64_t limb = exp.data[i];
        for (int j = 0; j < 64; ++j) {
            if (limb & 1) result *= b;
            b *= b;
            limb >>= 1;
        }
    }
    return result;
}


void init_goldilocks_field();



} // namespace libff

#endif
