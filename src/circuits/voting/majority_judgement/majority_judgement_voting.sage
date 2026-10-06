from proving_pipeline.circuit_wrapper.circuit import Circuit
import random

class Majority_judgement_voting(Circuit):
    def __init__(self, params):
        super().__init__(params)

    def generate_random_ballot(self, n_cand, n_grades):
        votes = [[0 for j in range(n_grades)] for i in range(n_cand)]
        for i in range(n_cand):
            pos_one_vote = random.randint(0, n_grades - 1)
            votes[i][pos_one_vote] = 1
        self.votes = votes
        return votes
    
    def generate_input(self, existing_input, constants):
        input = {}
        n_cand = int(self.retrieve_global_data("constants", "n_cand", constants))
        n_grades = int(self.retrieve_global_data("constants", "n_grades", constants))
        ballot = self.generate_random_ballot(n_cand, n_grades)
        linearized_ballot = []
        for row in ballot:
            linearized_ballot += row
        input["linearized_ballot"] = linearized_ballot

        self.input = input
        return input

    def generate_constants(self, existing_constants, index=None):
        constants = {}
        n_cand = int(self.retrieve_global_data("constants", "n_cand", existing_constants))
        n_grades = int(self.retrieve_global_data("constants", "n_grades", existing_constants))
        if not n_cand:
            n_cand = 10
        if not n_grades:
            n_grades = 6
        constants["bits_votes"] = 32,
        constants["n_cand"] = n_cand
        constants["n_grades"] = n_grades
        constants["n_cand_times_n_grades"] = n_cand * n_grades

        return constants

    def serialize(self):
        state = super().serialize()
        if self.votes:
            state["params"]["votes"] = self.votes
        return state

    def deserialize(self, state):
        super().deserialize(state)
        if state["params"].get("votes"):
            self.votes = [int(vote) for vote in state["params"]["votes"]]