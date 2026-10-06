import os
import sys
import time
import shutil
import copy
from datetime import datetime
import json
import re

from scripts.JSON import JSONUtils
from utils.utils import Utils
from proving_pipeline.pipeline_manager import Pipeline_Manager
from proving_pipeline.config_processor.config_processor import Config_Processor
from proving_pipeline.circuit_wrapper.circuit import Circuit

# !!! IMPORTANT: Needs to be run using sage !!!

# Increase Javascript heap memory
os.environ["NODE_OPTIONS"] = "--max-old-space-size=16384"

class ProvingPipeline:
    def __init__(self, meta_config_path):
        self.meta_config_path = meta_config_path
        self.cwd = os.getcwd()
        self.initial_files = os.listdir(self.cwd)
        
        # Timing and state variables
        self.time = time.time()
        self.step_results = {}
        self.config = {}
        self.steps = {}
        self.resume_updates = {}  # Tracks new files/states to append to resume config
        
        # Pipeline objects
        self.language_utils = None
        self.circuits_params = []
        self.circuits = []
        self.merged_template = None
        self.original_constants = {}
        self.current_constants = {}
        self.original_input = {}
        self.current_input = {}
        self.instantiated_circuit = None
        self.circuit_processor = None
        self.circuit_stats = {"non_linear_constraints": 0, "linear_constraints": 0, "total_constraints": 0}
        self.r1cs = None
        self.backend_prover = None
        self.prover_setup = {}
        self.crs_size_bytes = 0
        self.wtns = None
        self.proof = None
        self.instance = None
        
        self.diff_files = []
        self.full_path = None

    def _record_time(self, step_key, start_time=None):
        """Helper to record the duration of a step."""
        tmp_time = start_time if start_time else self.time
        self.step_results[step_key] = (time.time() - tmp_time) * 1000

    def run(self):
        """Executes the pipeline steps in correct order."""
        self.merge_meta_config()
        self.merge_templates()
        self.generate_constants()
        self.instantiate_circuit()
        self.generate_r1cs()
        self.setup_prover()
        self.generate_input()
        self.create_wtns()
        self.prove()
        self.verify()
        self.save_results()
        self.export_pipeline_status()
        self.cleanup()

    def merge_meta_config(self):
        raw_config = JSONUtils.destringify_json(JSONUtils.load_file(self.meta_config_path))
        self.raw_meta_config = copy.deepcopy(raw_config) # Preserve original structure for resume_config

        # 1. Resolve Shorthand Mappings
        if isinstance(raw_config, list):
            mappings_path = "proving_pipeline/config_processor/meta_config_mappings.json"
            if os.path.exists(mappings_path):
                # print("Hi")
                mappings = JSONUtils.load_file(mappings_path)
                mapped_paths = []
                for item in raw_config:
                    # Only resolve if the dictionary has exactly one key named "config"
                    if isinstance(item, dict) and len(item) == 1 and "config" in item:
                        config_shorthands = item["config"]
                        if isinstance(config_shorthands, dict):
                            for key, val in config_shorthands.items():
                                if isinstance(val, str) and key in mappings and val in mappings[key]:
                                    mapped_paths.append(mappings[key][val])
                                    
                # Append the resolved paths to the list so Config_Processor loads them
                if mapped_paths:
                    raw_config.extend(mapped_paths)
                # print(f"Mapped config: {json.dumps(mapped_paths)}")

        # 2. Pre-determine if we need to merge
        should_merge = True
        if isinstance(raw_config, dict) and "pipeline_steps" in raw_config:
            should_merge = raw_config["pipeline_steps"].get("merge_meta_config", True)

        start = time.time()
        if should_merge:
            if isinstance(raw_config, list):
                # Write to temp file to utilize Config_Processor's deep-merge
                temp_filename = "temp_meta_config_for_merge.json"
                JSONUtils.save_file(raw_config, temp_filename)
                self.config = Config_Processor.load_and_merge_meta_config(temp_filename)
                if os.path.exists(temp_filename):
                    os.remove(temp_filename)
            else:
                self.config = Config_Processor.load_and_merge_meta_config(self.meta_config_path)
            self._record_time("t_config_processing[ms]", start)
        else:
            self.config = raw_config
            # self._record_time("t_config_processing[ms]", start)

        # 3. Restore Temporary Files
        tmp_dir = self.config.get("tmp_files_directory")
        if tmp_dir and os.path.exists(tmp_dir):
            print(f"Restoring temporary files and directories from {tmp_dir} to working directory...")
            for item in os.listdir(tmp_dir):
                src = os.path.join(tmp_dir, item)
                dst = os.path.join(self.cwd, item)
                if os.path.isdir(src):
                    shutil.copytree(src, dst, dirs_exist_ok=True)
                elif os.path.isfile(src) and not os.path.exists(dst):
                    shutil.copy2(src, dst)

        # 4. Parse Pipeline Steps
        self.steps = {
            "merge_meta_config": True, "merge_templates": True, "generate_constants": True,
            "instantiate_circuit": True, "generate_r1cs": True, "setup_prover": True,
            "generate_input": True, "create_wtns": True, "prove": True, "verify": True,
            "save_results": True, "delete_tmp_files": False
        }
        if "pipeline_steps" in self.config:
            self.steps.update(self.config["pipeline_steps"])
        self.config["pipeline_steps"] = self.steps

        # print(f"Config: {json.dumps(self.config, indent=4)}")
        self.language_utils = Pipeline_Manager.get_language_utils(self.config["circuit_language"])
        self.circuits_params = self.config["circuits"]

        self.config = JSONUtils.destringify_json(self.config)

    def merge_templates(self):
        if self.steps["merge_templates"]:
            self.time = time.time()
            self.merged_template = self.language_utils.merge_templates(self.circuits_params)
            self.config["merged_circuit"] = self.merged_template
            self.resume_updates["merged_circuit"] = self.merged_template
            self._record_time("t_circuit_creation[ms]")
        else:
            if "merged_circuit" in self.config:
                self.merged_template = self.config["merged_circuit"]
            else:
                if len(self.circuits_params) != 1:
                    raise ValueError("Pipeline Step 'merge_templates' is False, and 'merged_circuit' not found, but 'circuits' does not contain exactly 1 item.")
                self.merged_template = self.circuits_params[0]["template"]

    def generate_constants(self):
        self.original_constants = self.config.get("constants", {})
        self.current_constants = copy.deepcopy(self.original_constants)

        if self.steps["generate_constants"]:
            start = time.time()
            merged_constants, self.circuits = Circuit.generate_merged_constants(self.circuits_params, self.current_constants)
            
            JSONUtils.save_file(merged_constants, "generated_constants.json")
            self.config["generated_constants_file"] = "generated_constants.json"
            self.resume_updates["generated_constants_file"] = "generated_constants.json"
            self.current_constants = merged_constants
            
            self._record_time("t_constants_generation[ms]", start)
        else:
            if "generated_constants_file" in self.config:
                gen_c = JSONUtils.load_file(self.config["generated_constants_file"])
                self.current_constants.update(gen_c)

            # print(f"Config: {json.dumps(self.config, indent=4)}")
            self.individual_circuits_states_path = self.config["individual_circuits_states"]
            individual_circuits_saved_states = JSONUtils.load_file(self.individual_circuits_states_path)
            for circuit_state in individual_circuits_saved_states:
                circuit = Utils.deserialize_from_state(circuit_state)
                self.circuits.append(circuit)
            print(f"Loaded individual circuits from {self.individual_circuits_states_path}.")
            if not self.circuits and self.steps["generate_input"]:
                raise ValueError("Pipeline Step 'generate_input' is False, but 'circuits' missing.")

    def instantiate_circuit(self):
        original_input = self.config.get("input", {})
        if self.steps["instantiate_circuit"]:
            start = time.time()
            merged_circuit = Circuit({"template": self.merged_template, "constants": self.current_constants, "input": original_input})
            self.instantiated_circuit = self.language_utils.instantiate_circuit(merged_circuit, original_input, self.current_constants)
            self.config["instantiated_circuit"] = self.instantiated_circuit.template
            self.resume_updates["instantiated_circuit"] = self.instantiated_circuit.template
                
            self._record_time("t_circuit_instantiation[ms]", start)
        else:
            self.instantiated_circuit_state_path = self.config["instantiated_circuit_state"]
            instantiated_circuit_state = JSONUtils.load_file(self.instantiated_circuit_state_path)
            self.instantiated_circuit = Utils.deserialize_from_state(instantiated_circuit_state)
            print(f"Loaded instantiated circuit from {self.instantiated_circuit_state_path}.")
            if not self.instantiated_circuit and (self.steps["generate_r1cs"] or self.steps["create_wtns"]):
                raise ValueError("Pipeline Step 'instantiate_circuit' is False, but 'instantiated_circuit' missing.")

    def generate_r1cs(self):
        self.circuit_processor = Pipeline_Manager.get_circuit_processor(self.config["circuit_processor"])
        
        if self.steps["generate_r1cs"]:
            start = time.time()
            self.r1cs, circuit_stats_ret = self.circuit_processor.create_r1cs(self.instantiated_circuit)
            self.circuit_stats.update(circuit_stats_ret)
            self.config["r1cs"] = self.r1cs
            self.resume_updates["r1cs"] = self.r1cs
            self._record_time("t_r1cs_creation[ms]", start)
        else:
            self.r1cs = self.config.get("r1cs")
            if not self.r1cs and (self.steps["setup_prover"] or self.steps["prove"]):
                 raise ValueError("Pipeline Step 'generate_r1cs' is False, but 'r1cs' file missing.")

    def setup_prover(self):
        self.backend_prover = Pipeline_Manager.get_prover_backend(self.config["backend_prover"])
        self.backend_prover.set_basename(self.instantiated_circuit.template.split(".")[0])

        if self.steps["setup_prover"]:
            start = time.time()
            self.prover_setup, self.crs_size_bytes = self.backend_prover.setup()
            self.config["prover_setup"] = self.prover_setup
            self.resume_updates["prover_setup"] = self.prover_setup
            self._record_time("t_prover_setup[ms]", start)
        else:
            self.prover_setup = self.config.get("prover_setup", {})
            if not self.prover_setup and (self.steps["prove"] or self.steps["verify"]):
                raise ValueError("Pipeline Step 'setup_prover' is False, but 'prover_setup' missing.")
            
            if "crs" in self.prover_setup and os.path.exists(self.prover_setup["crs"]):
                self.crs_size_bytes = os.path.getsize(self.prover_setup["crs"])

    def generate_input(self):
        self.original_input = self.config.get("input", {})
        self.current_input = copy.deepcopy(self.original_input)

        if self.steps["generate_input"]:
            start = time.time()
            merged_input, self.circuits = Circuit.generate_merged_input(
                self.circuits_params, self.current_input, self.circuits, self.current_constants
            )
            
            JSONUtils.save_file(JSONUtils.stringify_json(merged_input), "generated_input.json")
            self.config["generated_input_file"] = "generated_input.json"
            self.resume_updates["generated_input_file"] = "generated_input.json"
            
            if hasattr(self.instantiated_circuit, "set_input"):
                self.instantiated_circuit.set_input(merged_input)
                
            self._record_time("t_input_generation[ms]", start)
        else:
            if "generated_input_file" in self.config:
                gen_i = JSONUtils.load_file(self.config["generated_input_file"])
                self.current_input.update(gen_i)
            if hasattr(self.instantiated_circuit, "set_input"):
                self.instantiated_circuit.set_input(self.current_input)

    def create_wtns(self):
        if self.steps["create_wtns"]:
            start = time.time()
            self.wtns = self.circuit_processor.create_wtns(self.instantiated_circuit)
            self.config["wtns"] = self.wtns
            self.resume_updates["wtns"] = self.wtns
            self._record_time("t_wtns_creation[ms]", start)
        else:
            self.wtns = self.config.get("wtns")
            if not self.wtns and self.steps["prove"]:
                raise ValueError("Pipeline Step 'create_wtns' is False, but 'wtns' missing.")

    def prove(self):
        if self.steps["prove"]:
            start = time.time()
            self.proof, self.instance = self.backend_prover.prove()
            self.config["proof"] = self.proof
            self.config["instance"] = self.instance
            self.resume_updates["proof"] = self.proof
            self.resume_updates["instance"] = self.instance
            
            # Check if the prover supplied highly accurate internal times (e.g., Ligero)
            if hasattr(self.backend_prover, "extracted_prove_time_ms") and self.backend_prover.extracted_prove_time_ms is not None:
                self.step_results["t_prover_prove[ms]"] = self.backend_prover.extracted_prove_time_ms
            else:
                self._record_time("t_prover_prove[ms]", start)
        else:
            self.proof = self.config.get("proof")
            self.instance = self.config.get("instance")
            if not self.proof and self.steps["verify"]:
                raise ValueError("Pipeline Step 'prove' is False, but 'proof' missing.")
            if not self.instance and self.steps["verify"]:
                raise ValueError("Pipeline Step 'prove' is False, but 'instance' missing.")

    def verify(self):
        if self.steps["verify"]:
            start = time.time()
            self.backend_prover.verify()
            
            # Check if the prover supplied highly accurate internal times (e.g., Ligero)
            if hasattr(self.backend_prover, "extracted_verify_time_ms") and self.backend_prover.extracted_verify_time_ms is not None:
                self.step_results["t_prover_verify[ms]"] = self.backend_prover.extracted_verify_time_ms
            else:
                self._record_time("t_prover_verify[ms]", start)

    def save_results(self):
        """Saves benchmark timings and stats if enabled."""
        if not self.steps["save_results"]:
            return

        if self.steps["generate_r1cs"]:
             self.step_results["non_linear_constraints"] = self.circuit_stats.get("non_linear_constraints", 0)
             self.step_results["linear_constraints"] = self.circuit_stats.get("linear_constraints", 0)
             self.step_results["total_constraints"] = self.circuit_stats.get("total_constraints", 0)
             
        if self.crs_size_bytes:
             self.step_results["crs_size[MB]"] = self.crs_size_bytes / (1000**2)

        results_path = self.config.get("results", {}).get("path", "results/")
        if not os.path.exists(results_path):
            os.makedirs(results_path)

        if "results" not in self.config or not isinstance(self.config["results"], dict):
             self.config["results"] = {}
        self.config["results"].update(self.step_results)
            
        base_name = os.path.splitext(os.path.basename(self.meta_config_path))[0]
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"{base_name}_{timestamp}.json"
        self.full_path = os.path.join(results_path, filename)
        
        JSONUtils.exportToJSON(self.config, self.full_path)
        print(f"Benchmark results saved to: {self.full_path}")

    def export_circuit_states(self, clean_base_name, iteration):
        instantiated_circuit_state_filename = f"{clean_base_name}_instantiated_circuit_state_{iteration}.json"
        self.instantiated_circuit_state_path = os.path.join(self.cwd, instantiated_circuit_state_filename)        
        instantiated_circuit_state = self.instantiated_circuit.serialize()
        JSONUtils.save_file(instantiated_circuit_state, self.instantiated_circuit_state_path)
        print(f"Instantiated circuit state saved to: {self.instantiated_circuit_state_path}")
        
        # Only save filename into config to guarantee cross-machine portability
        self.config["instantiated_circuit_state"] = instantiated_circuit_state_filename
        self.resume_updates["instantiated_circuit_state"] = instantiated_circuit_state_filename

        individual_circuits_states_filename = f"{clean_base_name}_individual_circuits_states_{iteration}.json"
        self.individual_circuits_states_path = os.path.join(self.cwd, individual_circuits_states_filename)
        individual_circuits_states = [circuit.serialize() for circuit in self.circuits]
        JSONUtils.save_file(individual_circuits_states, self.individual_circuits_states_path)
        print(f"Individual circuits states saved to: {self.individual_circuits_states_path}")
        
        # Only save filename into config
        self.config["individual_circuits_states"] = individual_circuits_states_filename
        self.resume_updates["individual_circuits_states"] = individual_circuits_states_filename

    def export_pipeline_status(self):
        """Saves the updated meta config with local paths."""
        base_name = os.path.splitext(os.path.basename(self.meta_config_path))[0]
        
        # Strip any existing "_resume_config" or "_resume_config_X" suffixes
        clean_base_name = re.sub(r'_resume_config(?:_\d+)?$', '', base_name)

        # Determine the iteration counter and prepare the flattened resume list
        iteration = 1
        resume_config = copy.deepcopy(self.raw_meta_config)
        
        if isinstance(resume_config, list):
            last_item = resume_config[-1]
            # Check if the last item is an update block from a previous run
            if isinstance(last_item, dict) and "resume_iteration" in last_item:
                iteration = last_item["resume_iteration"] + 1
        
        # Carry over the accumulated results into the new update block
        if "results" in self.config:
            self.resume_updates["results"] = self.config["results"]
            
        # Update our tracking counter
        self.resume_updates["resume_iteration"] = iteration

        # Export states using the clean name and iteration number
        self.export_circuit_states(clean_base_name, iteration)

        resume_filename = f"{clean_base_name}_resume_config_{iteration}.json"
        self.resume_path = os.path.join(self.cwd, resume_filename)
        
        if isinstance(resume_config, list):
            last_item = resume_config[-1]
            if isinstance(last_item, dict) and "resume_iteration" in last_item:
                # Update the existing update block instead of appending a new one
                last_item.update(self.resume_updates)
            else:
                # First time resuming: append the new update block
                resume_config.append(self.resume_updates)
        else:
            # Fallback for flat dict
            resume_config = self.config
            resume_config.update(self.resume_updates)

        JSONUtils.exportToJSON(resume_config, self.resume_path)
        print(f"Resume Config saved to: {self.resume_path}")

    def cleanup(self):
        # 1. Identify all files added during this execution
        final_files = os.listdir(self.cwd)
        self.diff_files = [f for f in final_files if f not in self.initial_files]

        tmp_dir = self.config.get("tmp_files_directory")
        exceptions = [os.path.abspath(self.full_path)] if self.full_path else []
        diff = [f for f in self.diff_files if os.path.abspath(f) not in exceptions]

        if tmp_dir:
            if not os.path.exists(tmp_dir):
                os.makedirs(tmp_dir)
            
            for f in diff:
                if os.path.abspath(f) == os.path.abspath(tmp_dir):
                    continue
                try:
                    # Safely overwrite if the file/directory already exists in tmp_dir
                    dest_path = os.path.join(tmp_dir, f)
                    if os.path.exists(dest_path):
                        if os.path.isdir(dest_path):
                            shutil.rmtree(dest_path)  # Delete old directory
                        else:
                            os.remove(dest_path)      # Delete old file
                            
                    shutil.move(f, dest_path)
                except Exception as e:
                    print(f"Warning: Could not move {f} to {tmp_dir}: {e}")
            
            if self.steps["delete_tmp_files"]:
                try: shutil.rmtree(tmp_dir)
                except: pass
        else:
            if self.steps["delete_tmp_files"]:
                Utils.delete_differences(self.cwd, self.initial_files, exceptions=exceptions)


if __name__ == "__main__":
    args = sys.argv[1:]
    if len(args) != 1:
        print("Usage: fullprove.py <meta_config.json>")
        sys.exit(1)

    pipeline = ProvingPipeline(args[0])
    pipeline.run()
