    
class Circuit_Processor():
    def __init__(self, params):
        self.params = params

    def create_r1cs(self, instantiated_circuit):
        raise NotImplementedError("Converting a circuit to r1cs format is specific to the Circuit Processor and needs to be implemented in the corresponding subclass.")
    
    def create_wtns(self, instantiated_circuit):
        raise NotImplementedError("Converting the input for a circuit to wtns format is specific to the Circuit Processor and needs to be implemented in the corresponding subclass.")
    
    def process_circuit(self, instantiated_circuit):
        r1cs_filepath = self.create_r1cs(instantiated_circuit)
        wtns_filepath = self.create_wtns(instantiated_circuit)

        return r1cs_filepath, wtns_filepath