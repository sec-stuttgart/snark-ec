from abc import abstractmethod

class Constants():
    """Base class for constants. All classes which can be turned into constants format or can produce constants need to inherit from this."""

    @abstractmethod
    def to_constants_format(self):
        pass

    @classmethod
    def array_to_constants_format(cls, obj):
        if hasattr(obj, "to_constants_format"):
            return obj.to_constants_format()
        elif isinstance(obj, list):
            return [Constants.array_to_constants_format(o) for o in obj]
        else:
            raise ValueError(f"Object of type {type(obj)} is not a list and does not have 'to_constants_format' function.")