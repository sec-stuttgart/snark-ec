from proving_pipeline.circuit_wrapper.circuit import Circuit
import random
import numpy as np

class Evaluate_election(Circuit):
    def __init__(self, params):
        super().__init__(params)

    def generate_random_tally(self, n_cand, n_grades, num_voters=100):
        """
        Generates a random tally matrix for a Majority Judgment election.

        Args:
            n_cand (int): Number of candidates.
            n_grades (int): Number of possible grades (e.g., 5 for Poor to Excellent).
            num_voters (int): Total number of voters.

        Returns:
            np.ndarray: A (n_cand x n_grades) matrix where element [i][j] 
                        is the count of voters who gave candidate i grade j.
        """
        # Initialize the tally matrix
        tally = np.zeros((n_cand, n_grades), dtype=int)

        for i in range(n_cand):
            # Step 1: Generate a random probability distribution for this specific candidate.
            # np.random.dirichlet takes a vector of "alphas". 
            # Using np.ones returns a uniform distribution over the simplex 
            # (meaning every possible distribution of votes is equally likely).
            probs = np.random.dirichlet(np.ones(n_grades))

            # Step 2: Distribute the num_voters into bins based on those probabilities.
            # This ensures sum(tally[i]) always equals num_voters.
            tally[i] = np.random.multinomial(num_voters, probs)

        return tally.tolist()
    
    def generate_constants(self, existing_constants, index=None):
        constants = {}
        n_cand = int(self.retrieve_global_data("constants", "n_cand", existing_constants))
        n_grades = int(self.retrieve_global_data("constants", "n_grades", existing_constants))
        if not n_cand:
            n_cand = 10
        if not n_grades:
            n_grades = 6
        constants["bits"] = 32,
        constants["n_cand"] = n_cand
        constants["n_grades"] = n_grades
        constants["n_cand_times_n_grades"] = n_cand * n_grades

        return constants
        
