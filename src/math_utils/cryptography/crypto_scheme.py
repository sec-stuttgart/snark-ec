from abc import ABC
from proving_pipeline.circuit_wrapper.circuit_format import Circuit_Format

class Crypto_Scheme(ABC, Circuit_Format):
    """
    The absolute root base class for all cryptographic schemes.
    Useful if you later want to add universal utility methods 
    (e.g., serialization, rng seeding) that all schemes share.
    """
    
    def __init__(self, name=None):
        super().__init__(name)