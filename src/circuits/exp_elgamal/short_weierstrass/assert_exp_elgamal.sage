from scripts.sageImport import sage_import
from proving_pipeline.circuit_wrapper.circuit import Circuit
from scripts.JSON import JSONUtils
from utils.utils import Utils
from proving_pipeline.circuit_wrapper.constants import Constants
from proving_pipeline.circuit_wrapper.input import Input
import json
import random 
import numpy as np
sage_import('utils/sage_utils', fromlist=['Sage_utils'])
sage_import('math_utils/cryptography/encryption/asymmetric/exponential_elgamal', fromlist=['Exponential_Elgamal'])

class Assert_exp_elgamal(Circuit):
    def __init__(self, params):
        super().__init__(params)
        self.eeg = None

    def generate_constants(self, existing_constants, index=None):
        base_plain = self.params["base_plain"]
        bits_plain = self.retrieve_global_data("constants", "bits_plain", existing_constants)
        digits_plain = Sage_utils.compute_digits(bits_plain, base_plain)

        base_rand = self.params["base_rand"]
        bits_rand = self.params["bits_rand"]
        digits_rand = Sage_utils.compute_digits(bits_rand, base_rand)
        # print(f"Plain: {digits_plain} digits in base {base_plain},\nRand: {digits_rand} digits in base {base_rand}.")

        constants = existing_constants
        constants["rand_base_check"] = self.params["rand_base_check"]
        constants["base_plain"] = base_plain
        constants["digits_plain"] = digits_plain
        constants["base_rand"] = base_rand
        constants["digits_rand"] = digits_rand
        curve_params = self.params["curve"]
        constants["SW_a"] = curve_params["SW_a"]
        constants["SW_b"] = curve_params["SW_b"]
        curve_subgroup_order = Integer(curve_params["order"])//Integer(curve_params["cofactor"])

        self.eeg = Exponential_Elgamal(curve_params)

        self.g = self.eeg.pub_key["g"]
        self.h = self.eeg.pub_key["h"]
        
        powers_of_g_plain = self.g.generate_optimized_powers_for_M_SW(base_plain, digits_plain)
        powers_of_g_rand = self.g.generate_optimized_powers_for_M_SW(base_rand, digits_rand)
        powers_of_pk_rand = self.h.generate_optimized_powers_for_M_SW(base_rand, digits_rand)

        constants["powers_of_g_plain"] = Constants.array_to_constants_format(powers_of_g_plain)
        constants["powers_of_g_rand"] = Constants.array_to_constants_format(powers_of_g_rand)
        constants["powers_of_pk_rand"] = Constants.array_to_constants_format(powers_of_pk_rand)
        constants["g"] = Constants.array_to_constants_format(self.g)
        constants["pk"] = Constants.array_to_constants_format(self.h)

        self.constants = constants
        return constants
    
    def generate_input(self, existing_input, constants, index=None):
        base_plain = int(self.params["base_plain"])
        base_rand = int(self.params["base_rand"])
        digits_plain = int(self.retrieve_global_data("constants", "digits_plain", constants))
        digits_rand = int(self.retrieve_global_data("constants", "digits_rand", constants))
        curve_params = self.params["curve"]
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
            # print("Could not retrieve existing plain value, choosing one at random.")
            plain = random.randint(0, base_plain**digits_plain-1)
            # plain = 1
            # plain = 762316480
    
        rand = random.randint(0, subgroup_order - 1)
        # TESTING:
        # rand = 0
        # plain = 0
        # print(f"Index: {index}")
        # print(f"Random value at index {index}: {rand}")
        # rand = subgroup_order - 1
        # print(f"EEG pubkey: \n\tg: {self.eeg.pub_key['g'].serialize()}\nh: {self.eeg.pub_key['h'].serialize()}")

        plain_indices = Sage_utils.genBaseIndices(plain, digits_plain, base_plain)
        rand_indices = Sage_utils.genBaseIndices(rand, digits_rand, base_rand)
        # print(f"Plain: value {plain}") # indices {plain_indices}
        # print(f"Rand: value {rand}") # indices {rand_indices}

        eeg_ciphertext = self.eeg.encrypt(plain, rand=rand)

        input["v"] = plain
        input["r"] = rand
        input["v_indices"] = plain_indices
        input["r_indices"] = rand_indices
        input["gr"] = eeg_ciphertext["gr"].to_input_format()
        input["gv_pkr"] = eeg_ciphertext["gplain_hr"].to_input_format()

        self.input = input
        return input

    def serialize(self):
        state = super().serialize()
        if self.eeg:
            state["params"]["eeg"] = self.eeg.serialize()
        # print(f"EEG: {json.dumps(state, indent=4)}")
        return state

    def deserialize(self):
        super().deserialize(state)
        if state["params"].get("eeg"):
            self.eeg = Exponential_Elgamal()
            self.eeg.deserialize(state["params"]["eeg"])
