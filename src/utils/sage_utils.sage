import math
import random

class Sage_utils:
    @classmethod
    def toBaseIndices(cls, number, digits, base):
        base_indices=[]
        for j in range(0, digits):
            digit_indices = [0 for i in range(0, base)]
            digit = Integer(str(number)) % base
            digit_indices[digit] = 1
            number = Integer(str(number)) // base
            base_indices.append(digit_indices)
        return base_indices

    @classmethod
    def genBaseIndices(cls, array, digits, base):
        """
        Generates an array with the same shape as the input array, filled with random numbers.
        """
        if isinstance(array, list):
            return [Sage_utils.genBaseIndices(subarray, digits, base) for subarray in array]
        else:
            return Sage_utils.toBaseIndices(array, digits, base)

    @classmethod
    def compute_digits(cls, bits, base):
        """
        Computes the number of digits needed to represent a value with bits many bits in base base.
        """
        # print(f"Bits: {bits}")
        return int(math.ceil(bits * math.log(2, base)))

    @classmethod
    def compute_slots(cls, bits, bits_vote):
        """
        Computes the number of digits needed to represent a value with bits many bits in base base.
        """
        # print(f"Bits: {bits}")
        return int(math.floor(bits/bits_vote))

    @classmethod
    def compute_gen(cls, n_entries, num_slots):
        """
        Computes the number of digits needed to represent a value with bits many bits in base base.
        """
        # print(f"Bits: {bits}")
        return int(math.ceil(n_entries/num_slots))

    @classmethod
    def generate_random_ranking(cls, n):
        """
        Generates a ranking with potential ties at arbitrary places
        """
        ranking = [random.randint(0, n - 1) for i in range(n)]
        print(ranking)
        return ranking

    @classmethod
    def check_bases_optimized_montgomery_scalar_mul(cls, subgroup_order, max_base=128):
        """
        Computes, for which bases the optimized montgomery scalar mul with a value of at most subgroup_order - 1 will work.
        In that case, the maximal sum of all precomputed values up to the second last digit needs to be less than the group order.
        """
        field = GF(subgroup_order)
        print(f"Field: {field}")
        possible_bases = []
        for base in range(2, max_base + 1):
            digits = math.ceil(math.log(Integer(subgroup_order), Integer(base)))
            terms = [field((base-1))*base**i + 1 for i in range(0, digits-3)] # Max modified terms for digits 0 to digits-3
            terms.append(base**(digits-1)) # Max modified term for digit digits-2
            worst_case_sum = Integer(sum(terms))
            base_possible = worst_case_sum < Integer(subgroup_order)
            print(f"Base: {base}, digits: {digits}, Base usable: {base_possible}")
            print(f"Worst case sum: {worst_case_sum}") # - subgroup_order: {worst_case_sum-subgroup_order}"
            if base_possible:
                possible_bases.append(base)
        return possible_bases
