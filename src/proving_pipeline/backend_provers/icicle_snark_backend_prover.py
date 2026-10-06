from proving_pipeline.backend_provers.snarkjs_backend_prover import Snarkjs_Backend_Prover
from utils.utils import Utils
import os
import re
import subprocess

class Icicle_Backend_Prover(Snarkjs_Backend_Prover):
    def __init__(self, params):
        super().__init__(params)

    # def verify(self, crs, proof, instance):
    #     basename = crs.split(".")[0]
    #     Utils.execute_shell_command(f"snarkjs zkey export verificationkey {crs} {basename}_verification_key.json")
    #     verification_key = f"{basename}_verification_key.json"
    #     return self.call_snark_specific_func("verify", verification_key, proof, instance, basename)
    
    def groth16_prove(self, crs, wtns):
        device = self.params["device"]

        # The command we want to type into the prompt
        internal_cmd = f"prove --witness {wtns} --zkey {crs} --proof {self.basename}_proof.json --public {self.basename}_public.json --device {device}\n"
        
        print("Starting ICICLE-Snark worker...")
        
        # 1. Open the interactive tool in the background
        process = subprocess.Popen(
            ["icicle-snark"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,  # Merges errors into the standard output
            text=True
        )
        
        # 2. Type the command into the tool and press Enter
        process.stdin.write(internal_cmd)
        process.stdin.flush()
        
        # 3. Read the output line-by-line
        for line in process.stdout:
            print(line, end="")  # Print it to your terminal so you can still see the progress
            
            # 4. As soon as the command is done, break our reading loop
            if "COMMAND_COMPLETED" in line:
                break
                
        # 5. Forcefully kill the tool before it goes into an infinite loop
        process.terminate()
        process.wait()

        return f"{self.basename}_proof.json", f"{self.basename}_public.json"
