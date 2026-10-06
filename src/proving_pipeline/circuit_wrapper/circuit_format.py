from proving_pipeline.circuit_wrapper.serializable import Serializable
from proving_pipeline.circuit_wrapper.constants import Constants
from proving_pipeline.circuit_wrapper.input import Input

class Circuit_Format(Serializable, Constants, Input):
    def __init__(self, name=None):
        super().__init__()
        self.name = name

    def serialize(self):
        state = super().serialize()
        if self.name:
            state["name"] = self.name
        return state
        
    def deserialize(self, state):
        super().deserialize(state)
        if state.get("name"):
            self.name = state["name"]
