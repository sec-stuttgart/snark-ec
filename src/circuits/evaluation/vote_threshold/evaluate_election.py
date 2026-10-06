from proving_pipeline.circuit_wrapper.circuit import Circuit
import random
from circuits.evaluation.linear_tally_circuit import Linear_tally_circuit

class Evaluate_election(Linear_tally_circuit):
    def __init__(self, params):
        super().__init__(params)

    def evaluate_tally(self, tally, constants):
        """
        Marks all candidates who received at least 'threshold' votes as winners.
        """
        threshold = int(self.retrieve_global_data("constants", "threshold", constants))
        return [1 if votes >= threshold else 0 for votes in tally]

    