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
sage_import('math_utils/elliptic_curves/ShortWeierstrass', fromlist=['ShortWeierstrassPoint'])
sage_import('math_utils/cryptography/commitment/pvc', fromlist=['Pvc'])

class Assert_pvc(Circuit):
    def __init__(self, params=None):
        super().__init__(config=params)
        self.gen = None
        self.pk = None
        self.pvc = None

    def generate_constants(self, existing_constants, index=None):
        base_plain = self.params["base_plain"]
        base_rand = self.params["base_rand"]
        bits_plain = self.retrieve_global_data("constants", "bits_plain", existing_constants)
        # print(f"Bits plain {bits_plain}, Base rand {base_rand}, Base plain {base_plain}")
        digits_plain = Sage_utils.compute_digits(bits_plain, base_plain)
        bits_rand = self.params["bits_rand"]
        digits_rand = Sage_utils.compute_digits(bits_rand, base_rand)
        # print(f"Plain: {digits_plain} digits in base {base_plain},\nRand: {digits_rand} digits in base {base_rand}.")

        n_entries = self.retrieve_global_data("constants", "n_entries", existing_constants)
        num_slots_plain = Sage_utils.compute_slots(bits_rand, bits_plain)
        num_gen_plain = Sage_utils.compute_gen(n_entries, num_slots_plain)

        constants = existing_constants
        constants["rand_base_check"] = self.params["rand_base_check"]
        constants["with_packing"] = self.params["with_packing"]
        constants["base_plain"] = base_plain
        constants["digits_plain"] = digits_plain
        constants["base_rand"] = base_rand
        constants["digits_rand"] = digits_rand
        constants["num_slots_plain"] = num_slots_plain
        constants["num_gen_plain"] = num_gen_plain
        curve_params = self.params["curve"]
        constants["SW_a"] = curve_params["SW_a"]
        constants["SW_b"] = curve_params["SW_b"]
        curve_subgroup_order = Integer(curve_params["order"])//Integer(curve_params["cofactor"])

        self.pvc = Pvc(n_entries, curve_params)
        
        self.g = self.pvc.gen
        self.pk = self.pvc.h
        powers_of_g_plain = [gen.generate_optimized_powers_for_M_SW(base_plain, digits_plain) for gen in self.g]
        powers_of_pk_rand = self.pk.generate_optimized_powers_for_M_SW(base_rand, digits_rand)

        constants["powers_of_g_plain"] = Constants.array_to_constants_format(powers_of_g_plain)
        constants["powers_of_pk_rand"] = Constants.array_to_constants_format(powers_of_pk_rand)
        constants["g"] = Constants.array_to_constants_format(self.g)
        constants["pk"] = Constants.array_to_constants_format(self.pk)

        self.constants = constants
        return constants

    def pack_plain_vector(self, plain, base_plain, digits_plain, num_slots, num_gen):
        """
        Produces a vector of length num_gen.
        Each entry is a packed window of size num_slots.
        """
        B = base_plain ** digits_plain
        packed = [0] * num_gen

        for g in range(num_gen):
            acc = 0
            start = g * num_slots

            for i in range(num_slots):
                idx = start + i
                val = plain[idx] if idx < len(plain) else 0
                acc += val * (B ** i)

            packed[g] = acc

        return packed
    
    def generate_input(self, existing_input, constants, index=None):
        with_packing = int(self.retrieve_global_data("constants", "with_packing", constants))
        base_plain = int(self.params["base_plain"])
        base_rand = int(self.params["base_rand"])
        digits_plain = int(self.retrieve_global_data("constants", "digits_plain", constants))
        digits_rand = int(self.retrieve_global_data("constants", "digits_rand", constants))
        num_slots_plain = int(self.retrieve_global_data("constants", "num_slots_plain", constants))
        num_gen_plain = int(self.retrieve_global_data("constants", "num_gen_plain", constants))
        curve_params = self.params["curve"]
        base_field = GF(curve_params["base_field"])
        order = base_field(curve_params["order"])
        cofactor = base_field(curve_params["cofactor"])
        subgroup_order = order // cofactor
        # print(f"Subgroup-order has {math.ceil(math.log(subgroup_order, 2))} bits.")

        n_entries = self.retrieve_global_data("constants", "n_entries", constants)

        input = {}

        plain=None
        # print(f"Index: {index}, existing input: {existing_input}")
        try:
            if index:
                plain = np.array(self.retrieve_global_data("input", "v", existing_input))[tuple(index)]
            else:
                tmp = self.retrieve_global_data("input", "v", existing_input)
                plain = [int(p) for p in tmp]
        except:
            print("Could not retrieve existing plain value, choosing one at random.")
            plain = [random.randint(0, base_plain**digits_plain-1) for i in range(n_entries)]
    
        rand = random.randint(0, subgroup_order - 1)
        # TESTING:
        # rand = 0
        # plain = 0
        # print(f"Index: {index}")
        # print(f"Random value at index {index}: {rand}")
        # rand = subgroup_order - 1

        plain_indices = [Sage_utils.genBaseIndices(p, digits_plain, base_plain) for p in plain]
        rand_indices = Sage_utils.genBaseIndices(rand, digits_rand, base_rand)
        # print(f"Plain: value {plain}") # indices {plain_indices}
        # print(f"Rand: value {rand}") # indices {rand_indices}

        commitment = None
        if with_packing == 1:
            packed = self.pack_plain_vector(
                plain,
                base_plain,
                digits_plain,
                num_slots_plain,
                num_gen_plain,
            )
            
            values = [0] * n_entries
            for i in range(min(num_gen_plain, n_entries)):
                values[i] = packed[i]
            
            commitment = self.pvc.commit(values, rand)[0]
        else:
            commitment = self.pvc.commit(plain, rand)[0]

        input["v"] = plain
        input["r"] = rand
        input["v_indices"] = plain_indices
        input["r_indices"] = rand_indices
        input["test_out"] = commitment.to_input_format()

        self.input = input
        return input

    def serialize(self):
        state = super().serialize()
        if self.pvc:
            state["params"]["pvc"] = self.pvc.serialize()
        return state

    def deserialize(self, state):
        super().deserialize(state)
        if state["params"].get("pvc"):
            self.pvc = Pvc()
            self.pvc.deserialize(state["params"]["pvc"])

