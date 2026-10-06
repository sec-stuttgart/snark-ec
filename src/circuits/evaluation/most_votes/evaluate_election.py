from proving_pipeline.circuit_wrapper.circuit import Circuit
import random
from circuits.evaluation.linear_tally_circuit import Linear_tally_circuit

class Evaluate_election(Linear_tally_circuit):
    def __init__(self, params):
        super().__init__(params)

    def evaluate_tally(self, tally, constants):
        """
        Marks the candidate(s) with the most votes as winners. Handles ties automatically.
        """
        if not tally:
            return []
            
        max_votes = max(tally)
        
        return [1 if votes == max_votes else 0 for votes in tally]

    