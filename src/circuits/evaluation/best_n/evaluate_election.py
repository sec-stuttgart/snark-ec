from proving_pipeline.circuit_wrapper.circuit import Circuit
import random
from circuits.evaluation.linear_tally_circuit import Linear_tally_circuit

class Evaluate_election(Linear_tally_circuit):
    def __init__(self, params):
        super().__init__(params)

    def evaluate_tally(self, tally, constants):
        """
        Marks the top 'n_best' candidates as winners. Includes all ties at the n_best-th position.
        """
        n_best = int(self.retrieve_global_data("constants", "n_best", constants))

        if not tally or n_best <= 0:
            return [0] * len(tally)
        if n_best >= len(tally):
            return [1] * len(tally)

        # Sort descending to find the cutoff score at the n-th position (index n-1)
        sorted_tally = sorted(tally, reverse=True)
        cutoff_score = sorted_tally[n_best - 1]

        # 1 if candidate meets or exceeds the cutoff, 0 otherwise
        return [1 if votes >= cutoff_score else 0 for votes in tally]

    