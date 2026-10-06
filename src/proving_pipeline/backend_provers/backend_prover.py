class Backend_Prover:
    def __init__(self, params):
        self.params = params

    def call_snark_specific_func(self, func_suffix, *args):
        snark = self.params["snark"]["name"]
        func = getattr(self, f"{snark}_{func_suffix}")
        if func:
            return func(*args)
        raise ValueError(f"Snark {snark} not supported")
    
    def set_basename(self, basename):
        self.basename = basename

    def setup(self):
        """
        Generate CRS
        """
        return self.call_snark_specific_func("setup")

    def prove(self):
        return self.call_snark_specific_func("prove")
    
    def verify(self):
        return self.call_snark_specific_func("verify")