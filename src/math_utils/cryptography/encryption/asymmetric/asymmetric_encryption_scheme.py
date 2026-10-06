from math_utils.cryptography.encryption.encryption_scheme import Encryption_Scheme
from abc import abstractmethod

class Asymmetric_Encryption_Scheme(Encryption_Scheme):
    """
    Asymmetric (Public-Key) Encryption Scheme.
    """
    
    @abstractmethod
    def generate_priv_key(self):
        """
        Generates and returns a secret key.
        """
        pass

    @abstractmethod
    def generate_pub_key(self):
        """
        Generates and returns a public key.
        """
        pass
