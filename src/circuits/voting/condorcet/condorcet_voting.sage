from scripts.sageImport import sage_import
from proving_pipeline.circuit_wrapper.circuit import Circuit
import random
sage_import('utils/sage_utils', fromlist=['Sage_utils'])

class Condorcet_voting(Circuit):
    def __init__(self, params):
        super().__init__(params)

    def compute_votes_from_ranking(self, ranking, n_cand):
        votes = [[0 for j in range(n_cand)] for i in range(n_cand)]
        for i in range(n_cand):
            for j in range(i+1, n_cand):
                ranked_the_same = (ranking[i] == ranking[j])
                ranked_worse = (ranking[i] > ranking[j])
                if ranked_worse:
                    votes[i][j] = 0
                    votes[j][i] = 1
                elif ranked_the_same:
                    votes[i][j] = 0
                    votes[j][i] = 0
                else: # ranked better
                    votes[i][j] = 1
                    votes[j][i] = 0
        self.votes = votes
        return votes

    def generate_random_ballot(self, n_cand):
        ranking = Sage_utils.generate_random_ranking(n_cand)
        votes = self.compute_votes_from_ranking(ranking, n_cand)
        self.ranking = ranking
        self.votes = votes
        return votes, ranking
    
    def generate_input(self, existing_input, constants):
        input = {}
        n_cand = int(self.retrieve_global_data("constants", "n_cand", constants))
        ballot, ranking = self.generate_random_ballot(n_cand)

        linearized_ballot = []
        for row in ballot:
            linearized_ballot += row
        input["linearized_ballot"] = linearized_ballot
        # input["ballot"] = ballot
        input["ranking"] = ranking

        self.input = input
        return input

    def generate_constants(self, existing_constants):
        constants = {}
        # print(f"existing constants: {existing_constants}")
        n_cand = int(self.retrieve_global_data("constants", "n_cand", existing_constants))
        if not n_cand:
            n_cand = 10
        constants["bits_votes"] = 32
        constants["n_cand"] = n_cand
        constants["n_cand_squared"] = n_cand*n_cand

        return constants

    def serialize(self):
        state = super().serialize()
        if self.votes:
            state["params"]["votes"] = self.votes
        if self.ranking:
            state["params"]["ranking"] = self.ranking
        return state

    def deserialize(self, state):
        super().deserialize(state)
        if state["params"].get("votes"):
            self.votes = [int(vote) for vote in state["params"]["votes"]]
        if state["params"].get("ranking"):
            self.ranking = [int(entry) for entry in state["params"]["ranking"]]