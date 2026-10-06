from math_utils.cryptography.encryption.encryption_scheme import Encryption_Scheme
from abc import abstractmethod

class Symmetric_Encryption_Scheme(Encryption_Scheme):
    """
    Symmetric (Secret-Key) Encryption Scheme.
    """
    
    @abstractmethod
    def generate_key():
        """
        Generates and returns a secret key.
        """
        pass