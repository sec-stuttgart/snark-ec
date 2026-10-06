from proving_pipeline.circuit_wrapper.circuit import Circuit
import random
from circuits.evaluation.majority_judgment.evaluate_election import Evaluate_election

class Evaluate_election_full(Evaluate_election):
    def __init__(self, params):
        super().__init__(params)

    def evaluate_tally(self, tally, n_votes):
        """
        Evaluates a Majority Judgment election with the standard tie-breaking procedure.

        Args:
            tally (list[list[int]]): A matrix where tally[i][j] is the count 
                                     of voters giving candidate i grade j.

        Returns:
            list[int]: An array of length n_cand where result[i] = 1 means 
                       candidate i won, and 0 means they lost.
        """
        n_cand = len(tally)
        if n_cand == 0:
            return []

        # Create a deep copy of the tally so we can modify vote counts 
        # without affecting the original input array
        working_tally = [row[:] for row in tally]

        # All candidates start as active
        active_candidates = list(range(n_cand))

        while len(active_candidates) > 1:
            medians = {}

            # 1. Compute the current median grade for each active candidate
            for c in active_candidates:
                total_votes = sum(working_tally[c])

                # Handle the rare edge case of a perfect, absolute tie where 
                # all votes have been depleted
                if total_votes == 0:
                    medians[c] = -1 
                    continue
                
                # Target index for the upper/exact median
                target_index = total_votes // 2
                cum_sum = 0

                for grade_index, count in enumerate(working_tally[c]):
                    cum_sum += count
                    if cum_sum > target_index:
                        medians[c] = grade_index
                        break

            # 2. Identify the best median grade among remaining candidates
            best_median = min(medians.values())

            # If all candidates ran out of votes, it's an unresolvable perfect tie
            if best_median == -1:
                break

            # 3. Eliminate anyone with a worse (higher) median grade
            active_candidates = [c for c in active_candidates if medians[c] == best_median]

            # 4. Tie-breaker: Remove ONE vote at the median grade for the remaining candidates
            if len(active_candidates) > 1:
                for c in active_candidates:
                    working_tally[c][best_median] -= 1

        # Format the final results list
        result = [0] * n_cand
        for c in active_candidates:
            result[c] = 1

        return result

    def generate_input(self, existing_input, constants):
        input = {}
        n_cand = int(self.retrieve_global_data("constants", "n_cand", constants))
        n_grades = int(self.retrieve_global_data("constants", "n_grades", constants))
        n_votes = int(self.retrieve_global_data("constants", "n_votes", constants))
        tally = self.generate_random_tally(n_cand, n_grades, n_votes)
        result = self.evaluate_tally(tally, n_votes)

        linear_tally = []
        for row in tally:
            linear_tally += row

        input["linear_tally"] = linear_tally
        input["test_out"] = result

        print(f"Tally: {tally}")
        print(f"Election result: {result}")

        return input