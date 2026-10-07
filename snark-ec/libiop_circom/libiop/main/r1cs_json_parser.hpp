#ifndef R1CS_JSON_PARSER_HPP
#define R1CS_JSON_PARSER_HPP

#include <string>
#include <libiop/relations/r1cs.hpp>
#include <libff/algebra/field_utils/bigint.hpp>
#include <libff/algebra/fields/goldilocks_field.hpp>
#include "field_element_parser.hpp"

template<typename FieldT>
void parse_r1cs_json(
    const std::string& filename,
    libiop::r1cs_constraint_system<FieldT>& r1cs,
    size_t primary_input_size,
    size_t auxiliary_input_size);

struct r1cs_metadata {
    size_t primary_input_size;
    size_t auxiliary_input_size;
    size_t num_constraints;
    size_t num_variables;
};

r1cs_metadata parse_r1cs_log(const std::string& log_filename);

#include "r1cs_json_parser.tcc"

#endif