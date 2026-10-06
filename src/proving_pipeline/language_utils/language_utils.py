import os
from proving_pipeline.circuit_wrapper.circuit import Circuit
from scripts.JSON import JSONUtils
import re
import json

class Language_Utils():
    def __init__(self, params):
        self.params = params

    def merge_templates(self, templates):
        raise NotImplementedError("Merging templates is specific to the circuit language. Needs to be implemented in the specific subclass!")
    
    def instantiate_circuit(self, circuit, input, constants):
        raise NotImplementedError("Instantiating templates with constants is specific to the circuit language. Needs to be implemented in the specific subclass!")
    
    def parse_template(self, template):
        raise NotImplementedError("Extracting input, output, constants and name from a template is specific to the circuit language. Needs to be implemented in the specific subclass!")
    
    
