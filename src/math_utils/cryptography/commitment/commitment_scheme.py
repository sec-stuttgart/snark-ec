from math_utils.cryptography.crypto_scheme import Crypto_Scheme
from abc import abstractmethod

class Commitment_Scheme(Crypto_Scheme):
    """Base class for all commitment schemes (e.g., Pedersen, Hash-based)."""

    def __init__(self, name=None):
        super().__init__(name)

    @abstractmethod
    def generate_public_parameters(self):
        """Generates public parameters required for the commitment (e.g., prime groups)."""
        pass

    @abstractmethod
    def commit(self, value):
        """
        Commits to a value. 
        Typically returns a tuple: (commitment_string, randomness).
        """
        pass

    @abstractmethod
    def open(self, commitment, value, randomness):
        """
        Verifies the commitment.
        Returns True if the commitment is valid for the given value and randomness info, else False.
        """
        pass