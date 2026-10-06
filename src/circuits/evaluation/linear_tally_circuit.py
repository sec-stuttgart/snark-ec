from proving_pipeline.circuit_wrapper.circuit import Circuit
import random
import numpy as np

class Linear_tally_circuit(Circuit):
    def __init__(self, params):
        super().__init__(params)

    def generate_random_tally(self, n_cand, num_votes=100):
        """
        Distributes a fixed number of votes randomly across a number of candidates.

        Args:
            n_cand (int): The number of candidates.
            num_voters (int): The total number of votes to distribute.

        Returns:
            numpy.ndarray: An array of size n_cand containing the vote counts.
        """
        if n_cand <= 0:
            raise ValueError("Number of candidates must be at least 1.")
        if num_votes < 0:
            raise ValueError("Number of voters cannot be negative.")
        
        # Assign equal probability (1/n_cand) for each candidate to get a vote
        probabilities = [1.0 / n_cand] * n_cand

        # The multinomial function handles the random distribution
        votes = np.random.multinomial(num_votes, probabilities)
    
        return votes.tolist()
    
    def generate_input(self, existing_input, constants):
        input = {}
        n_votes = int(constants.get("n_votes"))
        n_cand = self.retrieve_global_data("constants", "n_cand", constants)
        tally = self.generate_random_tally(n_cand, n_votes)
        result = self.evaluate_tally(tally, constants)

        input["tally"] = tally
        input["test_out"] = result

        print(f"Tally: {tally}")
        print(f"Election result: {result}")

        return input