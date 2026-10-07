#include <simdjson.h>
#include <fstream>
#include <regex>
#include <libff/algebra/field_utils/bigint.hpp>

template<typename FieldT>
void parse_r1cs_json(
    const std::string& filename,
    libiop::r1cs_constraint_system<FieldT>& r1cs,
    size_t primary_input_size,
    size_t auxiliary_input_size)
{
    r1cs.primary_input_size_ = primary_input_size;
    r1cs.auxiliary_input_size_ = auxiliary_input_size;

    simdjson::ondemand::parser parser;
    simdjson::padded_string json = simdjson::padded_string::load(filename);
    simdjson::ondemand::document doc = parser.iterate(json);

    auto constraints_array = doc["constraints"].get_array();

    size_t max_index_seen = 0;
    size_t constraint_count = 0;

    for (auto constraint_val : constraints_array)
    {
        libiop::linear_combination<FieldT> A, B, C;

        auto triple = constraint_val.get_array();
        size_t part = 0;

        for (auto lc_obj : triple)
        {
            libiop::linear_combination<FieldT>* target = nullptr;

            if (part == 0) target = &A;
            if (part == 1) target = &B;
            if (part == 2) target = &C;
            bool has_terms = false;
            for (auto field : lc_obj.get_object())
            {
                has_terms = true;
                std::string_view key = field.unescaped_key();
                std::string_view value = field.value().get_string();

                size_t index = std::stoull(std::string(key));

                if (index > max_index_seen)
                    max_index_seen = index;

                std::string s(value);  // convert string_view -> std::string
                FieldT coeff = parse_field_element<FieldT>(s);

                libiop::linear_term<FieldT> term;
                term.index_ = index;
                term.coeff_ = coeff;

                target->terms.emplace_back(std::move(term));
            }
            // If linear combination was empty, add a dummy term with index 0 and coeff 0
            if (!has_terms)
            {
                target->terms.emplace_back(libiop::linear_term<FieldT>{0, FieldT(0)});
            }
            part++;
        }

        r1cs.constraints_.emplace_back(A, B, C);

        constraint_count++;

        if (constraint_count % 100000 == 0) {
            std::cout << "Parsed "
                      << constraint_count
                      << " constraints\n";
        }
    }
}

r1cs_metadata parse_r1cs_log(const std::string& log_filename)
{
    std::ifstream in(log_filename);
    if (!in)
        throw std::runtime_error("Could not open log file");

    size_t public_inputs = 0;
    size_t public_outputs = 0;
    size_t private_inputs = 0;
    size_t wires = 0;
    size_t nonlinear = 0;
    size_t linear = 0;

    std::string line;
    while (std::getline(in, line))
    {
        if (line.find("public inputs:") != std::string::npos)
            public_inputs = std::stoull(line.substr(line.find(":") + 1));

        if (line.find("public outputs:") != std::string::npos)
            public_outputs = std::stoull(line.substr(line.find(":") + 1));

        if (line.find("private inputs:") != std::string::npos)
            private_inputs = std::stoull(line.substr(line.find(":") + 1));

        if (line.find("wires:") != std::string::npos)
            wires = std::stoull(line.substr(line.find(":") + 1));

        if (line.find("non-linear constraints:") != std::string::npos)
            nonlinear = std::stoull(line.substr(line.find(":") + 1));

        if (line.find("linear constraints:") != std::string::npos)
            linear = std::stoull(line.substr(line.find(":") + 1));
    }

    r1cs_metadata meta;

    meta.primary_input_size = public_inputs + public_outputs;

    meta.num_variables = wires; // This contains the constant 1

    meta.auxiliary_input_size =
        meta.num_variables - meta.primary_input_size; //This is actually one more than the number of actual private variables, since the variable count includes the constant 1

    meta.num_constraints = nonlinear + linear;

    return meta;
}