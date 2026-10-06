#ifndef FIELD_ELEMENT_PARSER_HPP
#define FIELD_ELEMENT_PARSER_HPP

#include <string>
#include <libff/algebra/fields/goldilocks_field.hpp>
#include <libff/algebra/field_utils/bigint.hpp>
#include <type_traits>

// ONLY FOR NEW GOLDILOCKS:
// // Specialization for Goldilocks
// template<typename FieldT, typename std::enable_if<std::is_same<FieldT, libff::goldilocks_Fp>::value, int>::type = 0>
// inline FieldT parse_field_element(const std::string& s) {
//     uint64_t val = std::stoull(s);
//     return FieldT(val);
// }

// // Generic version for fields with num_limbs
// template<typename FieldT, typename std::enable_if<!std::is_same<FieldT, libff::goldilocks_Fp>::value, int>::type = 0>
// inline FieldT parse_field_element(const std::string& s) {
//     constexpr size_t limbs = FieldT::num_limbs;
//     libff::bigint<limbs> b(s.c_str());
//     return FieldT(b);
// }

template<typename FieldT>
inline FieldT parse_field_element(const std::string& s) {
    constexpr size_t limbs = FieldT::num_limbs;
    libff::bigint<limbs> b(s.c_str());
    return FieldT(b);
}


#endif // FIELD_ELEMENT_PARSER_HPP