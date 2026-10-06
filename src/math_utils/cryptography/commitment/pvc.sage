from math_utils.cryptography.commitment.commitment_scheme import Commitment_Scheme
from abc import abstractmethod
from utils.utils import Utils

class Pvc(Commitment_Scheme):
    def __init__(self, n_entries=None, curve_params=None, name=None):
        super().__init__(name)
        self.curve_params = curve_params
        self.n_entries = n_entries
        if self.n_entries and self.curve_params:
            self.init()

    def init(self):
        self.referencePoint = Utils.create_class_reference_from_config(self.curve_params).getInfinity(self.curve_params)
        self.generate_public_parameters()

    def generate_public_parameters(self):
        # print(f"{self.n_entries}")
        self.gen = [self.referencePoint.getGenerator() for i in range(self.n_entries)]
        self.h = self.referencePoint.getGenerator()
        self.base_field = GF(self.curve_params["base_field"])

    def commit(self, values, randomness=None):
        r = self.base_field.random_element() if randomness == None else randomness
        res = self.h*r
        for i in range(self.n_entries):
            tmp = self.gen[i]*values[i]
            res += tmp
            # res += self.gen[i]*values[i]

        return res, r
    
    def open(self, commitment, values, randomness):
        recomputed_commitment = self.commit(values, randomness)[0]
        return commitment == recomputed_commitment

    def serialize(self):
        state = super().serialize()
        state["gen"] = [g.serialize() for g in self.gen]
        state["h"] = self.h.serialize()
        return state
        
    def deserialize(self, state):
        super().deserialize(state)
        self.h = Utils.deserialize_from_state(state["h"])
        # print(f"PVC h: {self.h}")
        self.gen = [Utils.deserialize_from_state(g) for g in state["gen"]]
        self.n_entries = len(self.gen)
        # print(f"#Entries: {self.n_entries}")
        self.curve_params = self.h.curve_params
        self.referencePoint = self.h
        self.base_field = GF(self.curve_params["base_field"])
