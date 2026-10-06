from scripts.sageImport import sage_import
from proving_pipeline.circuit_wrapper.circuit import Circuit
from scripts.JSON import JSONUtils
from utils.utils import Utils
import json
import random 
import numpy as np
sage_import('utils/sage_utils', fromlist=['Sage_utils'])
sage_import('math_utils/elliptic_curves/ShortWeierstrass', fromlist=['ShortWeierstrassPoint'])
sage_import('math_utils/cryptography/commitment/pedersen', fromlist=['Pedersen_Commitment'])

class Assert_pedersen_commitment(Circuit):
    def __init__(self, params):
        super().__init__(params)
        self.gen = None
        self.pk = None

    @classmethod
    def generate_optimized_powers(self, curve_point, base, digits, curve_subgroup_order):
        powers = []

        # Index 0 .. digits-4: With offset 1
        for d in range(digits-3):
            digit_powers = []
            for i in range(base):
                scalar = i*base**d + 1
                digit_powers.append(curve_point*scalar)
            powers.append(digit_powers)

        # Index digits - 3: With special offset base^{digits-3} + (base - (digits - 3) mod base)
        digit_powers = []
        for i in range(base):
            scalar = i*base**(digits-3) + base**(digits-3) + ((base - (digits - 3)) % base)
            digit_powers.append(curve_point*scalar)
            # print(f"Digit: {digits-3}, Value: {i}, Scalar: {scalar}")
        powers.append(digit_powers)

        # Index digits - 2: With special offset base
        digit_powers = []
        for i in range(base):
            scalar = i*base**(digits-2) + base
            digit_powers.append(curve_point*scalar)
        powers.append(digit_powers)

        # Index digits - 1: To remove added offsets: -base^{digits-3} - (digits-3) - base - (base - (digits - 3) mod base)
        digit_powers = []
        for i in range(base):
            scalar = (i*base**(digits-1) - base**(digits-3) - (digits-3) - base - ((base - (digits - 3)) % base)) % Integer(curve_subgroup_order)
            digit_powers.append(curve_point*scalar)
        powers.append(digit_powers)

        # sum_0_exp = powers[d][0] # 0
        # sum_1_exp = powers[0][1] # 1
        # for d in range(1, digits): # rest 0
        #     sum_0_exp += powers[d][0]
        #     sum_1_exp += powers[d][0]
        # 
        # print(f"Point: {curve_point}")
        # print(f"Exponent 0 value (should be infinity): {sum_0_exp}")
        # print(f"exponent 1 value (should be point): {sum_1_exp}")

        return powers
                

    def generate_constants(self, existing_constants, index=None):
        base_plain = self.wrapper_params["base_plain"]
        base_rand = self.wrapper_params["base_rand"]
        bits_plain = self.retrieve_global_data("constants", "bits_plain", existing_constants)
        digits_plain = Sage_utils.compute_digits(bits_plain, base_plain)
        bits_rand = self.wrapper_params["bits_rand"]
        digits_rand = Sage_utils.compute_digits(bits_rand, base_rand)
        print(f"Plain: {digits_plain} digits in base {base_plain},\nRand: {digits_rand} digits in base {base_rand}.")

        constants = existing_constants
        constants["base_plain"] = base_plain
        constants["digits_plain"] = digits_plain
        constants["base_rand"] = base_rand
        constants["digits_rand"] = digits_rand
        curve_params = self.wrapper_params["curve"]
        constants["SW_a"] = curve_params["SW_a"]
        constants["SW_b"] = curve_params["SW_b"]
        curve_subgroup_order = Integer(curve_params["order"])//Integer(curve_params["cofactor"])

        self.pedersen_commitment_scheme = Pedersen_Commitment(ShortWeierstrassPoint, curve_params)
        
        self.g = self.pedersen_commitment_scheme.gen
        self.pk = self.pedersen_commitment_scheme.h
        powers_of_g_plain = Assert_pedersen_commitment.generate_optimized_powers(self.g, base_plain, digits_plain, curve_subgroup_order)
        powers_of_pk_rand = Assert_pedersen_commitment.generate_optimized_powers(self.pk, base_rand, digits_rand, curve_subgroup_order)

        constants["powers_of_g_plain"] = JSONUtils.jsonToArray(JSONUtils.arrayToJSON(powers_of_g_plain))
        constants["powers_of_pk_rand"] = JSONUtils.jsonToArray(JSONUtils.arrayToJSON(powers_of_pk_rand))
        constants["g"] = JSONUtils.jsonToArray(self.g.toJSON())
        constants["pk"] = JSONUtils.jsonToArray(self.pk.toJSON())

        return constants
    
    def generate_input(self, existing_input, constants, index=None):
        base_plain = self.wrapper_params["base_plain"]
        base_rand = self.wrapper_params["base_rand"]
        digits_plain = self.retrieve_global_data("constants", "digits_plain", constants)
        digits_rand = self.retrieve_global_data("constants", "digits_rand", constants)
        curve_params = self.wrapper_params["curve"]
        base_field = GF(curve_params["base_field"])
        order = base_field(curve_params["order"])
        cofactor = base_field(curve_params["cofactor"])
        subgroup_order = order // cofactor
        # print(f"Subgroup-order has {math.ceil(math.log(subgroup_order, 2))} bits.")

        input = {}

        plain=None
        # print(f"Index: {index}, existing input: {existing_input}")
        try:
            if index:
                plain = np.array(self.retrieve_global_data("input", "v", existing_input))[tuple(index)]
            else:
                plain = int(self.retrieve_global_data("input", "v", existing_input))
        except:
            print("Could not retrieve existing plain value, choosing one at random.")
            plain = random.randint(0, base_plain**digits_plain-1)
            # plain = 1
            # plain = 762316480
    
        rand = random.randint(0, subgroup_order - 1)
        # TESTING:
        # rand = 0
        # plain = 0
        print(f"Index: {index}")
        # print(f"Random value at index {index}: {rand}")
        # rand = subgroup_order - 1

        plain_indices = Sage_utils.genBaseIndices(plain, digits_plain, base_plain)
        rand_indices = Sage_utils.genBaseIndices(rand, digits_rand, base_rand)
        print(f"Plain: value {plain}") # indices {plain_indices}
        print(f"Rand: value {rand}") # indices {rand_indices}

        commitment = self.pedersen_commitment_scheme.commit(plain, rand)[0]

        input["v"] = plain
        input["r"] = rand
        input["v_indices"] = plain_indices
        input["r_indices"] = rand_indices
        input["gv_pkr"] = commitment.toJSON()

        return input

