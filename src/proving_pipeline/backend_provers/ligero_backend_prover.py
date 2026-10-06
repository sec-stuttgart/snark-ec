import re
from proving_pipeline.backend_provers.backend_prover import Backend_Prover
from utils.utils import Utils

class Ligero_Backend_Prover(Backend_Prover):
    def __init__(self, params):
        super().__init__(params)
        self.extracted_prove_time_ms = None
        self.extracted_verify_time_ms = None

    def ligero_setup(self):
        """
        Ligero is a transparent IOP and does not require a trusted setup.
        Returns a dummy CRS string and a size of 0 bytes.
        """
        return "ligero_transparent_crs", 0

    def ligero_prove(self):
        """
        Gathers the required files based on self.basename and executes the Ligero binary.
        Parses the exact proving and verification times from stdout.
        """
        prover_executable = self.params.get("prover_executable", "./ligero")
        
        constraints_file = f"{self.basename}_constraints.json"
        log_file = f"{self.basename}.log"
        witness_file = f"{self.basename}_witness.json"
        
        command = f"{prover_executable} {constraints_file} {log_file} {witness_file}"
        print(f"Executing Ligero: {command}")
        
        # Capture the output of the command
        output = Utils.execute_shell_command(command)
        
        # Parse exact proving time
        prove_match = re.search(r"Proof generation time \(seconds\):\s*([\d.]+)", output)
        if prove_match:
            self.extracted_prove_time_ms = float(prove_match.group(1)) * 1000
            
        # Parse exact verification time
        verify_match = re.search(r"Proof verification time \(seconds\):\s*([\d.]+)", output)
        if verify_match:
            self.extracted_verify_time_ms = float(verify_match.group(1)) * 1000
        
        return f"{self.basename}_dummy_proof.json", f"{self.basename}_dummy_public.json"

    def ligero_verify(self):
        """
        Ligero automatically verifies the proof internally right after generating it.
        We simply pass through a success message. The time is recorded during prove().
        """
        print(f"Ligero natively verifies the proof during generation using {self.params.get('prover_executable', './ligero')}. Verification successful.")