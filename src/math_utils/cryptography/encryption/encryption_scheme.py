from math_utils.cryptography.crypto_scheme import Crypto_Scheme
from abc import abstractmethod

class Encryption_Scheme(Crypto_Scheme):
    """Base class for all encryption schemes."""

    @abstractmethod
    def encrypt(self, plaintext, key):
        """Encrypts the plaintext using the provided key."""
        pass

    @abstractmethod
    def decrypt(self, ciphertext, key):
        """Decrypts the ciphertext using the provided key."""
        pass