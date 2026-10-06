from proving_pipeline.circuit_wrapper.circuit import Circuit
import random
import numpy as np
import itertools
from typing import List, Tuple, Dict
from circuits.evaluation.irv.irv_tally_circuit import Irv_tally_circuit

class Evaluate_election_find_first_tie_breaker(Irv_tally_circuit):
    def __init__(self, params):
        super().__init__(params)

    

    def resolve_ties(self, round, tied_candidates: List[int], history: List[Dict[int, int]], constants) -> int:
        """
        Tie-breaking mechanism: Chooses the candidate with the lowest index.

        :param tied_candidates: List of candidate IDs tied for the fewest votes.
        :return: The candidate ID to be eliminated.
        """
        # Since we want the lowest index, we can just return the minimum of the IDs
        return min(tied_candidates)
    
    def generate_input(self, existing_input, constants):
        input = {}
        n_votes = int(constants.get("nVotes"))
        n_cand = int(self.retrieve_global_data("constants", "nCand", constants))
        n_rounds = int(self.retrieve_global_data("constants", "nRounds", constants))
        tally, rankings = self.generate_random_tally(n_cand, n_votes)
        n_rankings = len(rankings)
        result = self.evaluate_tally(n_cand, n_rounds, tally, rankings)

        input["tally"] = tally
        input["test_out"] = result

        print(f"Tally: {tally}")
        print(f"Election result: {result}")

        return input