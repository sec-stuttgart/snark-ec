#ifndef GOLDILOCKS_PP_HPP_
#define GOLDILOCKS_PP_HPP_

#include <libff/algebra/fields/goldilocks_field.hpp>

namespace libff {

class goldilocks_pp {
public:
    typedef goldilocks_Fp Fp_type;

    static void init_public_params();
};

} // namespace libff

#endif // GOLDILOCKS_PP_HPP_