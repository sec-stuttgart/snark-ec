from math_utils.cryptography.commitment.commitment_scheme import Commitment_Scheme
from abc import abstractmethod

class Pedersen_Commitment(Commitment_Scheme):
    def __init__(self, elliptic_curve_point_class, curve_params=None):
        super().__init__()
        self.curve_params = curve_params
        self.referencePoint = elliptic_curve_point_class.getInfinity(curve_params)
        self.generate_public_parameters()

    def generate_public_parameters(self):
        self.gen = self.referencePoint.getGenerator()
        self.h = self.referencePoint.getGenerator()
        self.base_field = GF(self.curve_params["base_field"])

    def commit(self, value, randomness=None):
        r = self.base_field.random_element() if randomness == None else self.base_field(randomness)
        return self.gen*self.base_field(value) + self.h*r, r
    
    def open(self, commitment, value, randomness):
        recomputed_commitment = self.commit(value, randomness)[0]
        return commitment == recomputed_commitment