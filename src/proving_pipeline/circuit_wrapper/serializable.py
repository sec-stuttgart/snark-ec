from abc import abstractmethod
import json

class Serializable():
    """Base class for serializable objects. All classes which can be serialized and deserialized need to inherit from this."""

    def get_info(self):
        return {
            "module_name" : self.__class__.__module__,
            "class_name" : self.__class__.__name__
        }

    @abstractmethod
    def serialize(self):
        return self.get_info()

    @abstractmethod
    def deserialize(self, state):
        pass
