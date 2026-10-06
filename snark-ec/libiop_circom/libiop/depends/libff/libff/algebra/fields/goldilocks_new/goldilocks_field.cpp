#include "goldilocks_field.hpp"
#include <random>

namespace libff {

goldilocks_Fp goldilocks_Fp::multiplicative_generator;
goldilocks_Fp goldilocks_Fp::root_of_unity;
goldilocks_Fp goldilocks_Fp::nqr;
goldilocks_Fp goldilocks_Fp::nqr_to_t;

uint64_t goldilocks_Fp::reduce(uint64_t x) {
    if (x >= modulus) x %= modulus;
    return x;
}

uint64_t goldilocks_Fp::reduce128(__uint128_t x) {
    uint64_t lo = (uint64_t)x;
    uint64_t hi = (uint64_t)(x >> 64);

    // first fold
    __uint128_t r = (__uint128_t)lo +
                    (__uint128_t)hi * 0xffffffffULL -
                    hi;

    uint64_t r_lo = (uint64_t)r;
    uint64_t r_hi = (uint64_t)(r >> 64);

    // second fold
    r = (__uint128_t)r_lo +
        (__uint128_t)r_hi * 0xffffffffULL -
        r_hi;

    uint64_t res = (uint64_t)r;

    if (res >= modulus) res -= modulus;
    return res;
}

goldilocks_Fp& goldilocks_Fp::operator+=(const goldilocks_Fp& other) {
    v += other.v;
    if (v >= modulus) v -= modulus;
    return *this;
}

goldilocks_Fp& goldilocks_Fp::operator-=(const goldilocks_Fp& other) {
    if (v >= other.v) v -= other.v;
    else v = modulus - (other.v - v);
    return *this;
}

goldilocks_Fp& goldilocks_Fp::operator*=(const goldilocks_Fp& other) {
    v = reduce128((__uint128_t)v * other.v);
    return *this;
}

goldilocks_Fp goldilocks_Fp::operator*(const goldilocks_Fp& other) const {
    return goldilocks_Fp(reduce128((__uint128_t)v * other.v));
}

goldilocks_Fp goldilocks_Fp::pow(uint64_t exp) const {
    goldilocks_Fp base = *this;
    goldilocks_Fp result = one();

    while (exp > 0) {
        if (exp & 1) result *= base;
        base *= base;
        exp >>= 1;
    }
    return result;
}

goldilocks_Fp& goldilocks_Fp::operator^=(unsigned long pow) { *this = this->pow(pow); return *this; }
goldilocks_Fp goldilocks_Fp::operator^(unsigned long pow) const { return this->pow(pow); }

goldilocks_Fp goldilocks_Fp::inverse() const {
    // Fermat: a^(p-2)
    return pow(modulus - 2);
}

goldilocks_Fp goldilocks_Fp::operator+(const goldilocks_Fp& other) const {
    goldilocks_Fp r = *this;
    r += other;
    return r;
}

goldilocks_Fp goldilocks_Fp::operator-(const goldilocks_Fp& other) const {
    goldilocks_Fp r = *this;
    r -= other;
    return r;
}

goldilocks_Fp goldilocks_Fp::operator-() const {
    if (is_zero()) return *this;
    return goldilocks_Fp(modulus - v);
}

bool goldilocks_Fp::operator==(const goldilocks_Fp& other) const {
    return v == other.v;
}

bool goldilocks_Fp::operator!=(const goldilocks_Fp& other) const {
    return v != other.v;
}

bool goldilocks_Fp::is_zero() const {
    return v == 0;
}

goldilocks_Fp goldilocks_Fp::squared() const {
    return (*this) * (*this);
}

goldilocks_Fp& goldilocks_Fp::square() {
    *this *= *this;
    return *this;
}

goldilocks_Fp& goldilocks_Fp::invert() {
    *this = inverse();
    return *this;
}

goldilocks_Fp goldilocks_Fp::zero() {
    return goldilocks_Fp(0);
}

goldilocks_Fp goldilocks_Fp::one() {
    return goldilocks_Fp(1);
}

goldilocks_Fp goldilocks_Fp::random_element() {
    static std::mt19937_64 rng(std::random_device{}());
    return goldilocks_Fp(rng());
}

std::ostream& operator<<(std::ostream& os, const goldilocks_Fp& a) {
    os << a.v;
    return os;
}

std::istream& operator>>(std::istream& is, goldilocks_Fp& a) {
    is >> a.v;
    a.v = goldilocks_Fp::reduce(a.v);
    return is;
}

std::vector<uint64_t> goldilocks_Fp::to_words() const {
    return { v };
}

bool goldilocks_Fp::from_words(std::vector<uint64_t> words) {
    if (words.size() != 1) return false;
    if (words[0] >= modulus) return false;
    v = words[0];
    return true;
}

void goldilocks_Fp::clear() {
    v = 0;
}

void goldilocks_Fp::randomize() {
    *this = random_element();
}

void init_goldilocks_field() {
    using F = goldilocks_Fp;

    // Known generator for Goldilocks
    F::multiplicative_generator = F(7);

    // 2^32-th root of unity
    F::root_of_unity =F(1753635133440165772ULL);

    // Quadratic non-residue
    F::nqr = F(7);

    F::nqr_to_t = F(1753635133440165772ULL);
}


}