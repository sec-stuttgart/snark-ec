template<typename FieldT>
void parse_witness_json(
    const std::string& filename,
    size_t primary_input_size,
    size_t auxiliary_input_size,
    libiop::r1cs_primary_input<FieldT>& primary_input,
    libiop::r1cs_auxiliary_input<FieldT>& auxiliary_input
)
{
    simdjson::ondemand::parser parser;
    simdjson::padded_string json = simdjson::padded_string::load(filename);
    simdjson::ondemand::document doc = parser.iterate(json);

    simdjson::ondemand::array witness_array = doc.get_array().value();

    primary_input.resize(primary_input_size);
    auxiliary_input.resize(auxiliary_input_size);

    size_t index = 0;
    for (simdjson::ondemand::value value : witness_array)
    {
        ++index;
        if (index == 1) continue; // skip constant 1

        // remove any non-digit characters (newlines, spaces, etc.)
        std::string s = std::string(value.get_string().value());
        s.erase(std::remove_if(s.begin(), s.end(),
                               [](unsigned char c){ return !std::isdigit(c); }),
                s.end());

        size_t adjusted_index = index - 2; // account for skipped first element
        if (adjusted_index < primary_input_size) {
            primary_input[adjusted_index] = parse_field_element<FieldT>(s);
        } else {
            size_t aux_index = adjusted_index - primary_input_size;
            auxiliary_input[aux_index] = parse_field_element<FieldT>(s);
        }
    }

    std::cout << "Witness parsed.\n";
    std::cout << "* Total entries (including constant): " << index << "\n";
    std::cout << "* Public Inputs: " << primary_input.size() << "\n";
    std::cout << "* Private Inputs: " << auxiliary_input.size() << "\n";
}