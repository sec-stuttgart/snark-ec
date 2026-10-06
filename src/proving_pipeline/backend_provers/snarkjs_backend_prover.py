from proving_pipeline.backend_provers.backend_prover import Backend_Prover
from utils.utils import Utils
import os
import re

class Snarkjs_Backend_Prover(Backend_Prover):
    def __init__(self, params):
        super().__init__(params)

    def retrieve_ptau_file(self):
        """
        Returns the file path. If __MAX__ is present, returns the path with the 
        highest natural number found in that position.

        Returns None if the file (or a matching variant) is not found.
        """
        placeholder = "__MAX__"
        filepath = self.params["snark"]["powers_of_tau"]

        # CASE 1: No placeholder used. Simply check existence.
        if placeholder not in filepath:
            return filepath if os.path.exists(filepath) else None

        # CASE 2: Placeholder used. Resolve highest number.
        directory = os.path.dirname(filepath)
        filename_template = os.path.basename(filepath)

        # Handle empty directory (relative paths like "file__MAX__.txt")
        if not directory:
            directory = "."

        if not os.path.exists(directory):
            return None

        # Construct a Regex to match the files
        # We split by placeholder, escape the text parts (to handle dots, etc.), 
        # and insert a regex group (\d+) to capture the number.
        parts = filename_template.split(placeholder)
        escaped_parts = [re.escape(p) for p in parts]
        pattern_str = "^" + r"(\d+)".join(escaped_parts) + "$"
        pattern = re.compile(pattern_str)

        max_num = -1
        best_file = None

        # Scan directory contents
        try:
            for fname in os.listdir(directory):
                match = pattern.match(fname)
                if match:
                    # Convert the captured number group to integer
                    # We use the first capture group corresponding to the first __MAX__
                    current_num = int(match.group(1))

                    if current_num > max_num:
                        max_num = current_num
                        best_file = os.path.join(directory, fname)
        except OSError:
            return None
        
        if best_file == None:
            raise FileNotFoundError("!!! No Ptau file found!!! Aborting...") 

        print(f"Using ptau file {best_file}")
        return best_file
    
    def setup(self):
        r1cs = f"{self.basename}.r1cs"
        final_zkey = f"{self.basename}.zkey"

        return self.call_snark_specific_func("setup", r1cs, final_zkey)
    
    def prove(self):
        crs = f"{self.basename}.zkey"
        wtns = f"{self.basename}.wtns"

        return self.call_snark_specific_func("prove", crs, wtns)

    def verify(self):
        crs = f"{self.basename}.zkey"
        Utils.execute_shell_command(f"snarkjs zkey export verificationkey {crs} {self.basename}_verification_key.json")
        verification_key = f"{self.basename}_verification_key.json"

        proof = f"{self.basename}_proof.json"
        instance = f"{self.basename}_public.json"

        return self.call_snark_specific_func("verify", verification_key, proof, instance)

    def groth16_setup(self, r1cs, final_zkey):
        initial_zkey = f"{self.basename}_0.zkey"
        # Create zkey file
        Utils.execute_shell_command(f"snarkjs groth16 setup {r1cs} {self.retrieve_ptau_file()} {initial_zkey}")
        # Contribute to zkey file
        Utils.execute_shell_command(f'snarkjs zkey contribute {initial_zkey} {final_zkey} --name="First Contribution" -v -e="{self.params["snark"]["contribution_randomness"]}"')
        # Get file size
        crs_size = os.path.getsize(final_zkey)
        # Export Verification
        return final_zkey, crs_size
    
    def groth16_prove(self, crs, wtns):
        Utils.execute_shell_command(f"snarkjs groth16 prove {crs} {wtns} {self.basename}_proof.json {self.basename}_public.json")
        return f"{self.basename}_proof.json", f"{self.basename}_public.json"
    
    def groth16_verify(self, verification_key, proof, instance):
        Utils.execute_shell_command(f"snarkjs groth16 verify {verification_key} {instance} {proof}")


    def plonk_setup(self, r1cs, final_zkey):
        Utils.execute_shell_command(f"snarkjs plonk setup {r1cs} {self.retrieve_ptau_file()} {final_zkey}")
        crs_size = os.path.getsize(final_zkey)
        return final_zkey, crs_size
    
    def plonk_prove(self, crs, wtns):
        Utils.execute_shell_command(f"snarkjs plonk prove {crs} {wtns} {self.basename}_proof.json {self.basename}_public.json")
        return f"{self.basename}_proof.json", f"{self.basename}_public.json"
    
    def plonk_verify(self, verification_key, proof, instance):
        Utils.execute_shell_command(f"snarkjs plonk verify {verification_key} {instance} {proof}")

    
    def fflonk_setup(self, r1cs, final_zkey):
        Utils.execute_shell_command(f"snarkjs fflonk setup {r1cs} {self.retrieve_ptau_file()} {final_zkey}")
        crs_size = os.path.getsize(final_zkey)
        return final_zkey, crs_size
    
    def fflonk_prove(self, crs, wtns):
        Utils.execute_shell_command(f"snarkjs fflonk prove {crs} {wtns} {self.basename}_proof.json {self.basename}_public.json")
        return f"{self.basename}_proof.json", f"{self.basename}_public.json"
    
    def fflonk_verify(self, verification_key, proof, instance):
        Utils.execute_shell_command(f"snarkjs fflonk verify {verification_key} {instance} {proof}")
