from scripts.JSON import JSONUtils
from utils.utils import Utils
from proving_pipeline.circuit_wrapper.circuit_format import Circuit_Format
import os
import re
import json
import shutil

class Circuit(Circuit_Format):
    def __init__(self, config=None):
        # print(json.dumps(config, indent=4))
        self.name = None
        if config:
            name = config.get("name")
            super().__init__(name=name)
            self.template = config["template"]
            self.params = config.get("params")
            self.constants = config["constants"]
            self.input = config["input"]
            self.mappings = config.get("mappings")

    def generate_constants(self, existing_constants, index=None):
        self.constants = existing_constants
        return existing_constants
    
    def set_constants(self, constants):
        self.constants = constants

    def get_constants(self):
        return self.constants
    
    def to_constants_format(self):
        return self.constants
    
    def generate_input(self, existing_input, constants, index=None):
        self.input = existing_input
        return existing_input

    def set_input(self, input):
        self.input = input

    def get_input(self):
        return self.input

    def to_input_format(self):
        return self.input 

    def export_input(self, filepath=None):
        if filepath == None:
            filepath = f"{Circuit.get_template_basename(self.template)}_input.json"
        JSONUtils.exportToJSON(self.to_input_format(), filepath)
        return filepath
    
    def serialize(self):
        state = super().serialize()
        state["template"] = self.template
        state["params"] = self.params
        state["constants"] = self.constants
        state["input"] = self.input
        state["mappings"] = self.mappings
        return state

    def deserialize(self, state):
        super().deserialize(state)
        self.template = state["template"]
        self.params = state["params"]
        self.constants = state["constants"]
        self.input = state["input"]
        self.mappings = state["mappings"]

    @classmethod
    def get_template_wrapper_module_name(cls, template_path):
        return str(template_path).replace("/", ".").removesuffix(".circom")
    
    @classmethod
    def get_template_wrapper_class_name(cls, template_path):
        base_name = Circuit.get_template_basename(template_path)
        return base_name.capitalize()

    @classmethod
    def get_template_basename(cls, template_path):
        base_name = os.path.splitext(os.path.basename(template_path))[0]  # e.g., 'file' from 'file.circom'
        return base_name
    
    def retrieve_global_data(self, data_dict_name, local_name, global_data):
        """
        Retrieves the gloabl value of data given the local name of it.
        """
        if data_dict_name not in ["input", "constants"]:
            raise ValueError(f"Could not retrieve data for {local_name} from global data '{data_dict_name}', only 'input' and 'constants' are supported.")
        else:
            return global_data.get(self.mappings[data_dict_name][local_name]["maps_to"])

    @classmethod 
    def create_circuit_instance(cls, circuit_config):
        """
        Dynamically import <circuit> class from <circuit>.py if it exists
        in the same directory as circuit_path or <circuit>.sage.py if it exists.
        """
        circuit_instance = None
        template_wrapper_module_name = Circuit.get_template_wrapper_module_name(circuit_config["template"])
        template_wrapper_class_name = Circuit.get_template_wrapper_class_name(circuit_config["template"])
        try:
            circuit_instance = Utils.create_instance_of_class(template_wrapper_module_name, template_wrapper_class_name, circuit_config)
        except (FileNotFoundError, ImportError) as e:
            # print(e)
            # try:
            base_dir = os.path.dirname(circuit_config["template"])
            base_name = Circuit.get_template_basename(circuit_config["template"])
            file_path_sage = os.path.join(base_dir, f"{base_name}.sage")

            # 1. Use --preparse to generate the .sage.py file
            Utils.execute_shell_command(f"sage --preparse {file_path_sage}")
            
            # 2. Rename the generated file so importlib can find it normally
            preparsed_file = os.path.join(base_dir, f"{base_name}.sage.py")
            target_py_file = os.path.join(base_dir, f"{base_name}.py")
            
            if os.path.exists(preparsed_file):
                shutil.move(preparsed_file, target_py_file)
            else:
                raise FileNotFoundError(f"Failed to preparse {file_path_sage}")

            print(f"Template wrapper module name: {template_wrapper_module_name}")

            circuit_instance = Utils.create_instance_of_class(template_wrapper_module_name, template_wrapper_class_name, circuit_config)
            # except:
            #     print(f"Circuit wrapper {file_path_py} and {file_path_sage} not found. Using default circuit class.")
            #     circuit_instance = Circuit(circuit_params)
        
        return circuit_instance
    
    @classmethod
    def generate_merged_input(cls, circuit_configs, existing_input, existing_circuits=None, constants=None):
        """
        Generates the merged input dictionary based on circuit generators
        and precedence rules.
        """
        return Circuit.generate_merged_data(circuit_configs, existing_input, "input", existing_circuits=existing_circuits, additional_params=constants)
    
    @classmethod
    def generate_merged_constants(cls, circuit_configs, existing_constants, existing_circuits=None):
        """
        Generates the merged constants dictionary based on circuit generators
        and precedence rules.
        """
        return Circuit.generate_merged_data(circuit_configs, existing_constants, "constants", existing_circuits=existing_circuits)
    
    @classmethod
    def generate_merged_data(cls, circuit_configs, existing_data, data_type, existing_circuits=None, additional_params=None):
        """
        Generic helper to generate merged inputs or constants.
        data_type must be "input" or "constants".

        Process in increasing precedence order (0 -> 1 -> 2), lower precedence numbers (0) overwrite higher ones (1).
        """
        if data_type not in ["input", "constants"]:
            raise ValueError("data_type must be 'input' or 'constants'")

        try:
            global_data = json.loads(json.dumps(existing_data))
        except:
            print(f"Parsing existing global {data_type} failed.")
            global_data = {} # Fallback

        # Sort by precedence: INCREASING order (reverse=False)
        sorted_configs = sorted(
            circuit_configs, 
            key=lambda c: c.get('precedence', float('inf')), 
            reverse=False
        )

        circuits = []
        for config in sorted_configs:
            # print(f"Template: {config['template']}")
            # 1. Instantiate the circuit wrapper
            circuit_instance = None
            relevant_circuits = []
            if existing_circuits:
                relevant_circuits = [circuit for circuit in existing_circuits if circuit.template == config["template"]]
            if len(relevant_circuits) > 0:
                circuit_instance = relevant_circuits[0]
            else:
                circuit_instance = Circuit.create_circuit_instance(config)
            
            # 2. Get the generating function and its arguments
            generating_func = getattr(circuit_instance, f"generate_{data_type}")

            gen_func_args = []
            if data_type == "input":
                gen_func_args = [global_data, additional_params]
            else:
                gen_func_args = [global_data]
            
            # Call the function *once* to get the list of local keys and values
            # (e.g., for the 'shared' behavior)
            initial_local_data = generating_func(*gen_func_args)

            # 3. Get shape and mapping rules
            shape_str = config["copies_shape"]

            shape_expressions = tuple(x.strip() for x in shape_str.strip('()').split(','))
            if shape_expressions == ('',): # Handle empty case like "()"
                shape_expressions = tuple()

            shape = []
            for expr in shape_expressions:
                dim = None
                try:
                    dim = int(expr)                    
                except:
                    if expr in global_data.keys():
                        dim = global_data[expr]
                    elif expr in additional_params.keys():
                        dim = additional_params[expr]
                    else:
                        raise ValueError(f"No value mapping for dimension {expr} in existing_data or additional_params.")
                shape.append(dim)
            shape = tuple(shape)
            mapping_rules = config["mappings"][data_type]

            local_data_array = None
            if(len([d for d in mapping_rules.values() if d["among_copies"] == "duplicated"]) > 1): # At least one data item is duplicated among the copies.
                # squeezed_dims = [d for d in shape if d > 1]
                squeezed_dims = [d for d in shape]
                local_data_array = Circuit.create_nested_array(squeezed_dims, generating_func, *gen_func_args)

            # 4. Map local data to global data
            for local_name, local_value in list(initial_local_data.items()):
                mapping = mapping_rules.get(local_name)

                if not mapping:
                    continue 
                
                global_name = mapping["maps_to"]
                behavior = mapping["among_copies"]

                # If the key already exists, SKIP.
                if global_name in global_data:
                    print(f"Global name {global_name} already mapped.")
                    continue

                if behavior == "shared":
                    # For "shared", we use the value from the single call
                    global_data[global_name] = local_value
                
                elif behavior == "duplicated":
                    global_data[global_name] = Circuit.retrieve_data_from_nested_array_of_jsons(local_data_array, local_name)

            circuits.append(circuit_instance)

        # print(f"Global data: {global_data}")
        return global_data, circuits
    
    @classmethod
    def retrieve_data_from_nested_array_of_jsons(cls, array, data_name):
        """
        Retrieves the all values for a given data name from this nested array of jsons
        """
        if isinstance(array, list):
            return [Circuit.retrieve_data_from_nested_array_of_jsons(array[i], data_name) for i in range(len(array))]
        elif isinstance(array, dict):
            return array[data_name]
        else:
            raise ValueError(f"Cannot retrieve value from object of type {type(array)}.")

    
    @classmethod
    def create_nested_array(cls, dims, generating_func, *args, index=None):
        """
        Recursively creates a nested list with given dimensions,
        filled with values generated by generating_func.
        e.g., dims=[2, 3], generating_func() = 5  -->  [[5, 5, 5], [5, 5, 5]]
        e.g., dims=[], generating_func() = 5      -->  5
        """
        # print(f"Index {index}, remaining dims: {dims}")
        if not dims:
            if index:
                # args = list[args]
                # args.append(index)
                # args = tuple(args)
                args += (index, )

            
            #  args: {args}")
            return generating_func(*args)
            
        if not index:
            index = []

        return [Circuit.create_nested_array(dims[1:], generating_func, *args, index=index + [i]) for i in range(dims[0])]
    
    

    



    
        