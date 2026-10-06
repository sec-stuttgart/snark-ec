from abc import ABC, abstractmethod
import random

class Group(ABC):
    def __init__(self):
        super().__init__()

    @abstractmethod
    def get_generator(self):
        """
        Returns a generator of this group
        """
        pass

    @abstractmethod
    def get_random_exponent(self):
        """
        Returns an exponent exponent in Z_n for group order n
        """
        return random.randint(0, self.order)