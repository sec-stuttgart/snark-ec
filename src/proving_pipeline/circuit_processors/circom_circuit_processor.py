import re
import struct
import json
import os

from proving_pipeline.circuit_processors.circuit_processor import Circuit_Processor
from utils.utils import Utils
from proving_pipeline.language_utils.language_utils import Language_Utils
from proving_pipeline.circuit_wrapper.circuit import Circuit

class Circom_Circuit_Processor(Circuit_Processor):
    def __init__(self, params):
        super().__init__(params)

    def parse_circom_stats_and_log(self, output, log_filepath):
        """
        Parses circom stdout in a single pass to both extract integer stats 
        for the pipeline and generate the exact .log file needed by Ligero.
        """
        stats = {
            "non_linear_constraints": 0,
            "linear_constraints": 0,
            "total_constraints": 0,
            "public_inputs": 0,
            "private_inputs": 0,
            "public_outputs": 0,
            "wires": 0,
            "labels": 0
        }
        
        # Tuples of (stat_key, string_prefix_in_output)
        fields_to_extract = [
            ("non_linear_constraints", "non-linear constraints"),
            ("linear_constraints", "linear constraints"), 
            ("public_inputs", "public inputs"),
            ("private_inputs", "private inputs"),
            ("public_outputs", "public outputs"),
            ("wires", "wires"),
            ("labels", "labels")
        ]

        log_lines = []

        for stat_key, field_name in fields_to_extract:
            # Negative lookbehind to prevent 'linear constraints' matching 'non-linear constraints'
            if field_name == "linear constraints":
                pattern = r"^(?<!non-)linear constraints:\s*(.*)$"
            else:
                pattern = rf"^{field_name}:\s*(.*)$"

            match = re.search(pattern, output, re.MULTILINE)
            if match:
                # Capture the full string value (e.g., "1085 (1007 belong to witness)")
                full_val_string = match.group(1).strip()
                log_lines.append(f"{field_name}: {full_val_string}")
                
                # Extract just the first integer for our stats dictionary
                int_match = re.search(r"(\d+)", full_val_string)
                if int_match:
                    stats[stat_key] = int(int_match.group(1))

        stats["total_constraints"] = stats["non_linear_constraints"] + stats["linear_constraints"]
        
        # Write out the properly formatted Ligero log file
        with open(log_filepath, "w") as f:
            f.write("\n".join(log_lines) + "\n")

        return stats

    def create_r1cs(self, instantiated_circuit):
        template_basename = Circuit.get_template_basename(instantiated_circuit.template)
        
        # Define paths for R1CS and our new Log file
        r1cs_filepath = f"{template_basename}.r1cs"
        log_filepath = f"{template_basename}.log"
        
        r1cs_command = f"circom {instantiated_circuit.template} --r1cs --sym --wasm --json {self.params['optimization']} --prime {self.params['prime']}"

        output = Utils.execute_shell_command(r1cs_command)
        
        # Call the updated parser to do both jobs at once
        stats = self.parse_circom_stats_and_log(output, log_filepath)

        return r1cs_filepath, stats

    def export_wtns_to_json(self, wtns_filepath, json_filepath):
        """
        Parses a Circom v2 .wtns binary file and exports it to a JSON array of strings.
        This is curve-independent and works for custom primes like P384.
        """
        if not os.path.exists(wtns_filepath):
            raise FileNotFoundError(f"Cannot find witness file: {wtns_filepath}")

        with open(wtns_filepath, 'rb') as f:
            # 1. Read Global Header
            magic = f.read(4)
            if magic != b'wtns':
                raise ValueError("Invalid .wtns file format.")

            version = struct.unpack('<I', f.read(4))[0]
            num_sections = struct.unpack('<I', f.read(4))[0]

            # 2. Read Section 1 (Metadata)
            sec1_id = struct.unpack('<I', f.read(4))[0]
            sec1_len = struct.unpack('<Q', f.read(8))[0]

            n8 = struct.unpack('<I', f.read(4))[0] # Size of prime field elements in bytes (48 for P384)
            prime_bytes = f.read(n8)              # The actual prime (we just skip it)
            nWtns = struct.unpack('<I', f.read(4))[0] # Total number of witness elements

            # 3. Read Section 2 (Witness Data)
            sec2_id = struct.unpack('<I', f.read(4))[0]
            sec2_len = struct.unpack('<Q', f.read(8))[0]

            witness_elements = []

            # Read each witness element (Little Endian)
            for _ in range(nWtns):
                val_bytes = f.read(n8)
                val_int = int.from_bytes(val_bytes, byteorder='little')
                witness_elements.append(str(val_int))

        # Write cleanly to JSON
        with open(json_filepath, 'w') as f:
            json.dump(witness_elements, f, indent=2)

        print(f"Successfully exported {nWtns} witness elements to {json_filepath}")

    def create_wtns(self, instantiated_circuit):
        template_basename = Circuit.get_template_basename(instantiated_circuit.template)
        input_filepath = instantiated_circuit.export_input()
        wtns_filepath = f"{template_basename}.wtns"
        wtns_command = f"node {template_basename}_js/generate_witness.js {template_basename}_js/{template_basename}.wasm {input_filepath} {wtns_filepath}"
        # wtns_json_export_command = f"snarkjs wtns export json {wtns_filepath} {template_basename}_witness.json"

        Utils.execute_shell_command(wtns_command)
        self.export_wtns_to_json(wtns_filepath, f"{template_basename}_witness.json")
        # Utils.execute_shell_command(wtns_json_export_command)

        return wtns_filepath
