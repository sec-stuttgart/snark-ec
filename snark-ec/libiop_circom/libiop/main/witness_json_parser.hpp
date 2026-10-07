#include <libiop/relations/r1cs.hpp>
#include <libff/algebra/fields/goldilocks_field.hpp>
#include "field_element_parser.hpp"

template<typename FieldT>
void parse_witness_json(
    const std::string& filename,
    size_t primary_input_size,
    size_t auxiliary_input_size,
    libiop::r1cs_primary_input<FieldT>& primary_input,
    libiop::r1cs_auxiliary_input<FieldT>& auxiliary_input
);

#include "witness_json_parser.tcc"