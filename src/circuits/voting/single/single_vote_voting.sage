from proving_pipeline.circuit_wrapper.circuit import Circuit
import random
from proving_pipeline.circuit_wrapper.constants import Constants
from proving_pipeline.circuit_wrapper.input import Input

class Single_vote_voting(Circuit):
    def __init__(self, params):
        super().__init__(params)
        self.votes = None

    def generate_random_ballot(self, n_votes):
        votes = [0 for i in range(n_votes)]
        pos_one_vote = random.randint(0, (n_votes * 6) // 5) # 0.2 Probability of abstention
        # pos_one_vote = random.randint(0, n_votes) # No abstention
        if pos_one_vote < n_votes:
            votes[pos_one_vote] = 1
        self.votes = votes
        return votes
    
    def generate_input(self, existing_input, constants):
        input = {}
        n_votes = int(self.retrieve_global_data("constants", "n_votes", constants))
        ballot = self.generate_random_ballot(n_votes)
        input["ballot"] = ballot

        self.input = input
        return input

    def serialize(self):
        state = super().serialize()
        if self.votes:
            state["params"]["votes"] = self.votes
        return state

    def deserialize(self, state):
        super().deserialize(state)
        if state["params"].get("votes"):
            self.votes = [int(vote) for vote in state["params"]["votes"]]