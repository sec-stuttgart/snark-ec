from proving_pipeline.circuit_wrapper.circuit import Circuit
import random
import numpy as np
import itertools
from typing import List, Tuple, Dict
from circuits.evaluation.irv.irv_tally_circuit import Irv_tally_circuit
from proving_pipeline.circuit_wrapper.constants import Constants
from proving_pipeline.circuit_wrapper.input import Input

class Evaluate_election_nsw_tie_breaker(Irv_tally_circuit):
    def __init__(self, params=None):
        super().__init__(params=params)

    def generate_tie_breaker_lots(self, n_cand: int, n_rounds: int, max_val: int = 10000) -> List[List[int]]:
        """
        Generates a 2D array [nRounds][nCand] of random lots for tie-breaking.
        Guarantees that lot values within the same round are unique.

        :param n_cand: Number of candidates.
        :param n_rounds: Number of elimination rounds.
        :param max_val: The maximum possible integer value for a lot.
        :return: A 2D list representing the public lots per round.
        """
        lots_matrix = []

        for r in range(n_rounds):
            # random.sample picks unique elements from the range, ensuring no two 
            # candidates get the same lot in the same round.
            round_lots = random.sample(range(1, max_val), n_cand)
            lots_matrix.append(round_lots)

        # print(f"Tie breakers:\n{lots_matrix}")
        return lots_matrix

    def resolve_ties(self, round: int, tied_candidates: List[int], history: List[Dict[int, int]], tie_breaker_lots) -> int:
        """
        Resolves ties using the New South Wales (NSW) method.
        Looks back at previous rounds to find the candidate with the fewest votes.
        Falls back to 'lots' if tied across all previous rounds.

        :param tied_candidates: List of currently tied candidate IDs.
        :param history: List of dictionaries mapping candidate IDs to their vote counts in past rounds.
                        history[0] is Round 1, history[-1] is Round r-1.
        :param lots: List of random/public lot values for each candidate.
        :return: The candidate ID to be eliminated.
        """
        current_tied = tied_candidates.copy()

        if len(current_tied) == 1:
                return current_tied[0]

        # Look backwards through the history (from round r-1 down to round 1)
        for past_round_votes in reversed(history):
            # Find the minimum votes among the CURRENTLY tied candidates in this past round
            min_votes = min(past_round_votes[c] for c in current_tied)

            # Filter the pool to only those who had that minimum vote count
            current_tied = [c for c in current_tied if past_round_votes[c] == min_votes]

            # If the tie is broken (only one candidate left), eliminate them!
            if len(current_tied) == 1:
                return current_tied[0]

        # --- Final Fallback: Public Lots ---
        # If we exhausted all history and they are STILL tied, use the public lots.
        # We assume the candidate with the smallest lot value is eliminated.
        min_lot = min(tie_breaker_lots[round][c] for c in current_tied)
        final_tied = [c for c in current_tied if tie_breaker_lots[round][c] == min_lot]
        print("Used tie breakers")

        # Absolute edge case: If the lots themselves are tied, pick the lowest index.
        return min(final_tied)

    def generate_input(self, existing_input, constants):
        input = {}
        n_votes = int(constants.get("nVotes"))
        n_cand = int(self.retrieve_global_data("constants", "nCand", constants))
        n_rounds = int(self.retrieve_global_data("constants", "nRounds", constants))
        bits = int(self.retrieve_global_data("constants", "bits", constants))
        tally, rankings = self.generate_random_tally(n_cand, n_votes)
        tie_breaker_lots = self.generate_tie_breaker_lots(n_cand, n_rounds, 2**bits - 1)
        n_rankings = len(rankings)
        result = self.evaluate_tally(n_cand, n_rounds, tally, rankings, tie_breaker_lots)

        input["tally"] = tally
        input["test_out"] = result
        input["tie_breaker_lots"] = tie_breaker_lots

        # print(f"Tally: {tally}")
        print(f"Election result: {result}")

        self.input = input
        return input