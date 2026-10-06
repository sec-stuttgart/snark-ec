import os
import sys
import json
import itertools
import copy
import subprocess
import time
from scripts.JSON import JSONUtils

def find_sweep_parameters(meta_config_list):
    """
    Traverses the meta_config list to find sweepable parameters.
    A parameter is considered 'sweepable' if it is a list of primitives (int, float, str, bool).
    
    Returns:
        sweeps (list): A list of tuples (path_to_key, list_of_values).
                       path_to_key is a list: [index_in_meta_list, key1, key2, ...]
    """
    sweeps = []

    for index, item in enumerate(meta_config_list):
        # We look for sweep params inside dictionary items and configs given as file paths
        if isinstance(item, dict):
            recurse_find_sweeps(item, [index], sweeps)
        elif isinstance(item, str):
            if not os.path.exists(item):
                print(f"Error: Configuration file not found: {item}")
                sys.exit(1)
            item = JSONUtils.load_file(item)
            recurse_find_sweeps(item, [index], sweeps)
            
    return sweeps

def recurse_find_sweeps(current_dict, current_path, sweeps):
    for key, value in current_dict.items():
        path = current_path + [key]
        
        # If it's a list, check if it's a list of primitives (sweepable) or objects (structural)
        if isinstance(value, list):
            if len(value) > 0 and not isinstance(value[0], (dict, list)):
                # Found a sweepable parameter (e.g., [16, 32, 64])
                sweeps.append((path, value))
            else:
                # It's likely a structural list (e.g., "circuits": [{...}]), do not sweep.
                pass
                
        # If it's a dictionary, recurse deeper
        elif isinstance(value, dict):
            recurse_find_sweeps(value, path, sweeps)

def apply_combination(meta_config_template, combination, sweep_defs):
    """
    Creates a specific meta_config instance by applying a single combination of values.
    """
    # Deep copy to ensure we don't modify the template for future iterations
    new_config = copy.deepcopy(meta_config_template)
    
    # sweep_defs is list of (path, values_list)
    # combination is tuple of selected values corresponding to sweep_defs
    for i, (path, _) in enumerate(sweep_defs):
        selected_value = combination[i]
        
        # Navigate to the correct location in the new_config
        # path[0] is the index in the meta_config list
        target = new_config[path[0]]
        
        # Traverse keys until the last one
        for key in path[1:-1]:
            target = target[key]
            
        # Set the specific scalar value, replacing the list
        target[path[-1]] = selected_value
        
    return new_config

def benchmark_meta_config(meta_config):
    if not isinstance(meta_config, list):
        print("Error: meta_config.json must be a list.")
        sys.exit(1)

    if isinstance(meta_config[0], list):
        print(f"Found {len(meta_config)} test suites, benchmarking all!")
        for meta_config_instance in meta_config:
            benchmark_meta_config(meta_config_instance)
        return

    print(f"--- Analyzing meta config instance for sweep parameters ---")
    
    # 1. Identify parameters to sweep
    # sweeps is a list of (path, potential_values)
    sweeps = find_sweep_parameters(meta_config)
    
    if not sweeps:
        print("No array-valued parameters found for benchmarking. Running once.")
        # Wrap in list of lists for logic consistency
        parameter_names = []
        value_combinations = [()]
    else:
        # 2. Generate Cartesian product of all combinations
        parameter_names = [".".join(str(p) for p in path[1:]) for path, vals in sweeps]
        parameter_values = [vals for path, vals in sweeps]
        value_combinations = list(itertools.product(*parameter_values))
        
        print(f"Found {len(sweeps)} sweepable parameters:")
        for name, vals in zip(parameter_names, parameter_values):
            print(f" - {name}: {vals}")
        print(f"Total benchmark runs to execute: {len(value_combinations)}")

    # 3. Iterate and Execute
    start_time = time.time()
    
    # Ensure a directory for temp configs exists
    temp_dir = "temp_benchmarks"
    if not os.path.exists(temp_dir):
        os.makedirs(temp_dir)

    for i, combo in enumerate(value_combinations):
        print(f"\n[{i+1}/{len(value_combinations)}] Preparing run...")
        
        if sweeps:
            # Print current config being run
            combo_str = ", ".join([f"{k}={v}" for k, v in zip(parameter_names, combo)])
            print(f"Parameters: {combo_str}")

        # Create the specific config for this run
        current_meta_config = apply_combination(meta_config, combo, sweeps)
        
        # Save to a temporary file
        temp_filename = os.path.join(temp_dir, f"temp_meta_config_{i}.json")
        JSONUtils.save_file(current_meta_config, temp_filename)
        
        # Run fullprove.py
        fullprove_script = "fullprove.py"
        cmd = [sys.executable, fullprove_script, temp_filename]
        
        try:
            subprocess.run(cmd, check=True)
        except subprocess.CalledProcessError as e:
            print(f"!!! Error during benchmark run {i+1}: {e}")
            # We continue to the next run even if one fails
            continue
        finally:
            # Optional: Remove temp file to keep clean
            if os.path.exists(temp_filename):
                os.remove(temp_filename)

    total_time = time.time() - start_time
    print(f"\n--- Benchmark Suite Completed in {total_time:.2f}s ---")


def main():
    if len(sys.argv) != 2:
        print("Usage: python benchmark.py <meta_config.json>")
        sys.exit(1)

    meta_config_path = sys.argv[1]
    
    if not os.path.exists(meta_config_path):
        print(f"Error: File not found: {meta_config_path}")
        sys.exit(1)

    try:
        meta_config = JSONUtils.load_file(meta_config_path)
    except Exception as e:
        print(f"Error parsing JSON: {e}")
        sys.exit(1)

    benchmark_meta_config(meta_config)

if __name__ == "__main__":
    main()