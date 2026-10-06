from abc import abstractmethod

class Input():
    """Base class for input. All classes which can be turned into input format or can produce input need to inherit from this."""

    @abstractmethod
    def to_input_format(self):
        pass

    @classmethod
    def array_to_input_format(cls, obj):
        if hasattr(obj, "to_input_format"):
            return obj.to_input_format()
        elif isinstance(obj, list):
            return [Input.array_to_input_format(o) for o in obj]
        else:
            raise ValueError(f"Object of type {type(obj)} is not a list and does not have 'to_input_format' function.")
