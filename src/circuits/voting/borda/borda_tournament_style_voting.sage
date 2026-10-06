from scripts.sageImport import sage_import
from proving_pipeline.circuit_wrapper.circuit import Circuit
import random
sage_import('utils/sage_utils', fromlist=['Sage_utils'])

class Borda_tournament_style_voting(Circuit):
    def __init__(self, params):
        super().__init__(params)

    def compute_votes_from_ranking(self, ranking, n_votes, a, b):
        votes = [0 for i in range(n_votes)]
        for i in range(n_votes):
            count_ranked_worse = sum((entry > ranking[i]) for entry in ranking)
            count_ranked_the_same = sum((entry == ranking[i]) for entry in ranking)
            votes[i] = a * count_ranked_worse + b * (count_ranked_the_same - 1) # (... -1) to exclude the entry at position i
        self.votes = votes
        return votes

    def generate_random_ballot(self, n_votes, a, b):
        ranking = Sage_utils.generate_random_ranking(n_votes)
        votes = self.compute_votes_from_ranking(ranking, n_votes, a, b)
        self.votes = votes
        self.ranking = ranking
        return votes, ranking

    def generate_input(self, existing_input, constants):
        input = {}
        n_votes = int(self.retrieve_global_data("constants", "n_votes", constants))
        a = int(self.retrieve_global_data("constants", "a", constants))
        b = int(self.retrieve_global_data("constants", "b", constants))
        ballot, ranking = self.generate_random_ballot(n_votes, a, b)
        input["ballot"] = ballot
        input["ranking"] = ranking

        self.input = input
        return input

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

    