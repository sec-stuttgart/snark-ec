from proving_pipeline.circuit_wrapper.circuit import Circuit
import random

class Line_vote_voting(Circuit):
    def __init__(self, params):
        super().__init__(params)

    def generate_random_ballot(self, n_votes):
        votes = [0 for i in range(n_votes)]
        pos_one_votes_start = random.randint(0, n_votes - 1)
        pos_one_votes_end = random.randint(0, n_votes - 1)
        if pos_one_votes_start <= pos_one_votes_end: # Otherwise: Abstention
            for i in range(pos_one_votes_start, pos_one_votes_end + 1):
                votes[i] = 1
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