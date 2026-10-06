from proving_pipeline.circuit_wrapper.circuit import Circuit
import random

class Multi_vote_with_rules_voting(Circuit):
    def __init__(self, params):
        super().__init__(params)

    def generate_random_ballot(self, n_votes, max_votes_per_candidate, max_votes_total):
        if n_votes < 3:
            raise ValueError("Need at least 3 entries in the ballot to enforce the additional constraint on the first three votes.")
        rest_votes = max_votes_total
        votes = [None]

        # Second entry:
        vote = random.randint(0, min(max_votes_per_candidate, rest_votes))
        votes.append(vote)
        rest_votes -= vote

        # Third entry:
        # We know:  rest_votes - votes[2] - votes[0] >= 0
        #       ->  rest_votes - votes[2] - votes[1]*votes[2] >= 0
        #       ->  rest_votes - (votes[1] + 1)*votes[2] >= 0
        #       ->  votes[2] <= rest_votes/(votes[1] + 1)
        #
        # Also:     votes[0] <= max_votes_per_candidate
        #       ->  votes[1] * votes[2] <= max_votes_per_candidate
        #       ->  votes[2] <= max_votes_per_candidate/votes[1]
        #
        # And:      votes[2] <= max_votes_per_candidate
        vote = random.randint(0, min(max_votes_per_candidate//max(1, votes[1]), rest_votes//(votes[1] + 1)))
        votes.append(vote)
        rest_votes -= vote

        # First entry:
        vote = votes[1] * votes[2]
        votes[0] = vote
        rest_votes -= vote

        # Other entries:
        for i in range(n_votes - 3):
            vote = random.randint(0, min(max_votes_per_candidate, rest_votes))
            votes.append(vote)
            rest_votes -= vote
        self.votes = votes
        return votes
    
    def generate_input(self, existing_input, constants):
        input = {}
        n_votes = int(self.retrieve_global_data("constants", "n_votes", constants))
        max_votes_per_candidate = int(self.retrieve_global_data("constants", "max_votes_cand", constants))
        max_votes_total = int(self.retrieve_global_data("constants", "max_choices", constants))
        ballot = self.generate_random_ballot(n_votes, max_votes_per_candidate, max_votes_total)
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


