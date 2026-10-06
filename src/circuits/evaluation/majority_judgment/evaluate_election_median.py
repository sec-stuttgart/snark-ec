from proving_pipeline.circuit_wrapper.circuit import Circuit
import random
from circuits.evaluation.majority_judgment.evaluate_election import Evaluate_election

class Evaluate_election_median(Evaluate_election):
    def __init__(self, params):
        super().__init__(params)

    def evaluate_tally(self, tally):
        """
        Calculates the Majority Grade (median) for each candidate.
        If the number of voters is even, it selects the Upper Median 
        (the larger of the two middle grades).

        Args:
            tally (list[list[int]]): A matrix where tally[i][j] is the count 
                                     of voters giving candidate i grade j.

        Returns:
            list[int]: An array of length n_cand containing the median grade 
                       index for each candidate.
        """
        results = []

        for candidate_votes in tally:
            total_voters = sum(candidate_votes)

            # We want the vote located at this index in the sorted list of grades.
            # Integer division // 2 automatically selects the "upper" median
            # for even numbers, and the exact median for odd numbers.
            median_target = total_voters // 2

            current_count = 0
            median_grade = 0

            # Iterate through grades (0, 1, 2...) accumulating vote counts
            for grade_index, vote_count in enumerate(candidate_votes):
                current_count += vote_count

                # As soon as our cumulative count passes the target index, 
                # we have found the median category.
                if current_count > median_target:
                    median_grade = grade_index
                    break
                
            results.append(median_grade)

        return results

    def generate_input(self, existing_input, constants):
        input = {}
        n_cand = int(self.retrieve_global_data("constants", "n_cand", constants))
        n_grades = int(self.retrieve_global_data("constants", "n_grades", constants))
        tally = self.generate_random_tally(n_cand, n_grades)
        result = self.evaluate_tally(tally)

        linear_tally = []
        for row in tally:
            linear_tally += row

        input["linear_tally"] = linear_tally

        input["tally"] = tally
        input["test_out"] = result

        # print(f"Tally: {tally}")
        # print(f"Election result: {result}")

        return input