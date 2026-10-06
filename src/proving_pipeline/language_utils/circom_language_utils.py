from proving_pipeline.language_utils.language_utils import Language_Utils
import re
from proving_pipeline.circuit_wrapper.circuit import Circuit
from itertools import product

class Circom_Language_Utils(Language_Utils):
    def __init__(self, params):
        super().__init__(params)

    def merge_templates(self, circuit_configs):
        """
        Merge multiple Circom circuits based on a list of configurations 
        from a presets.json file.
        
        Handles:
        - Multiple copies of templates ("copies_shape")
        - Mapping global constants to local template parameters
        - Mapping global inputs to local template inputs
        - "shared" vs. "duplicated" input/constant wiring
        - Generates component arrays and for loops.
        """
        includes = set()
        global_constant_decls = {} # e.g., {"delta": "delta[2][3]", "epsilon": "epsilon"}
        global_input_decls = {}  
        component_array_decls = [] 
        output_array_decls = []  
        instantiation_blocks = [] 
        
        merged_name_parts = ["MERGED"]
        all_template_chars = {} 

        # Step 1: Iterate through circuit configs to build declarations and components
        for config in circuit_configs:
            template_file = config["template"]
            
            if template_file not in all_template_chars:
                all_template_chars[template_file] = self.parse_template(template_file)
            template_chars = all_template_chars[template_file]
            
            template_name = template_chars["name"]
            includes.add(f'include "{template_file}";')
            merged_name_parts.append(template_name)

            # --- Squeeze Logic & Loop Setup ---
            shape_str = config["copies_shape"]

            shape_expressions = tuple(x.strip() for x in shape_str.strip('()').split(','))
            if shape_expressions == ('',): # Handle empty case like "()"
                shape_expressions = tuple()

            # 1. Get vars and dims ONLY for dimensions != "1"
            # e.g., shape_expressions=('1', 'n_votes') -> [('i_1', 'n_votes')]
            # squeezed_vars_dims = [(f"i_{idx}", expr) for idx, expr in enumerate(shape_expressions) if expr != "1"]
            squeezed_vars_dims = [(f"i_{idx}", expr) for idx, expr in enumerate(shape_expressions)]
            
            # 2. Extract lists from the squeezed data
            loop_vars = [v for v, d in squeezed_vars_dims]
            loop_bounds = [d for v, d in squeezed_vars_dims] # Now contains strings like 'n_votes'
            
            # 3. Dims string for array declarations (e.g., "[n_votes][n_votes+5]")
            array_dims = "".join(f"[{d}]" for d in loop_bounds)
            
            # 4. Accessor for use inside loops (e.g., "Foo[i_1]")
            comp_accessor = f"{template_name}{''.join(f'[{v}]' for v in loop_vars)}"
            
            # 5. Suffix for 'duplicated' inputs (e.g., "[i_1]")
            idx_suffix_for_wiring = "".join(f"[{v}]" for v in loop_vars)
            
            # 6. Loop headers (e.g., "for (var i_1 = 0; i_1 < n_votes; i_1++) {{")
            loop_headers = [f"    {'  ' * idx}for (var {var} = 0; {var} < {bound}; {var}++) {{" 
                            for idx, (var, bound) in enumerate(zip(loop_vars, loop_bounds))]
            loop_footers = [f"    {'  ' * idx}}}" 
                            for idx in reversed(range(len(loop_vars)))]
            
            # 7. Indentation level for code inside the loops
            indent = "    " + "  " * len(loop_vars)
            
            # --- Resolve Constants ---
            local_to_global_const_map = {} # e.g., {"alpha": "delta", "beta": "epsilon"}
            
            for local_name in template_chars["constants"]:
                mapping = config["mappings"]["constants"].get(local_name)

                if not mapping:
                    raise ValueError(f"Template {template_name} parameter '{local_name}' is not mapped.")
                
                global_name = mapping["maps_to"]
                behavior = mapping["among_copies"]
                
                local_to_global_const_map[local_name] = global_name
                
                final_dims = ""
                if behavior == "duplicated":
                    final_dims = array_dims # e.g., "[2][3]"
                
                new_decl = f"{global_name}{final_dims}" # e.g., "delta[2][3]" or "epsilon"
                
                if global_name in global_constant_decls and global_constant_decls[global_name] != new_decl:
                    raise ValueError(f"Constant '{global_name}' is mapped with conflicting dimensions:\n"
                                     f"  Existing: {global_constant_decls[global_name]}\n"
                                     f"  New:      {new_decl} (from template {template_name})")
                global_constant_decls[global_name] = new_decl

                for d in loop_bounds: # Add missing dimension constants
                    try: 
                        d = int(d)
                    except:
                        pass
                    finally:
                        if isinstance(d, str) and not global_constant_decls.get(d):
                            # print(f"Dimension: {d}")
                            global_constant_decls[d] = d

            # --- Resolve Inputs & Build Global Declarations ---
            for local_name in template_chars["input"].keys():
                type = template_chars["input"][local_name]["type"]
                local_dims = template_chars["input"][local_name]["dims"]
                mapping = config["mappings"]["input"].get(local_name)
                if not mapping:
                    raise ValueError(f"Template {template_name} input '{local_name}' is not mapped in presets.json")
                
                global_name = mapping["maps_to"]
                behavior = mapping["among_copies"]
                
                global_dims = local_dims
                
                for local_c, global_c in local_to_global_const_map.items():
                    global_dims = re.sub(r'\b' + re.escape(local_c) + r'\b', global_c, global_dims)
                
                final_dims = ""
                if behavior == "shared":
                    final_dims = global_dims
                elif behavior == "duplicated":
                    final_dims = array_dims + global_dims
                # print(f"Final dims for input {global_name} when reading template {template_name}: {final_dims}")
                
                new_decl = f"    input {type} {global_name}{final_dims};"
                
                if global_name in global_input_decls and global_input_decls[global_name] != new_decl:
                    raise ValueError(f"Input '{global_name}' is mapped with conflicting dimensions:\n"
                                     f"  Existing: {global_input_decls[global_name]}\n"
                                     f"  New:      {new_decl} (from template {template_name})")
                global_input_decls[global_name] = new_decl

            # --- Build Component & Output Array Declarations ---
            component_array_decls.append(f"    component {template_name}{array_dims};")
            for local_name in template_chars["output"].keys():
                type = template_chars["output"][local_name]["type"]
                global_out_name = f"{local_name}_{template_name}" 
                dims = template_chars["output"][local_name]["dims"]
                global_out_dims = dims
                for local_c, global_c in local_to_global_const_map.items():
                    global_out_dims = re.sub(r'\b' + re.escape(local_c) + r'\b', global_c, global_out_dims)
                output_array_decls.append(f"    output {type} {global_out_name}{array_dims}{global_out_dims};")

            # --- Build the Instantiation & Wiring Block ---
            current_block_lines = []
            current_block_lines.extend(loop_headers)
            
            param_strings = []
            for local_name in template_chars["constants"]:
                mapping = config["mappings"]["constants"].get(local_name)

                global_name = mapping["maps_to"]
                behavior = mapping["among_copies"]
                
                if behavior == "duplicated":
                    param_strings.append(f"{global_name}{idx_suffix_for_wiring}") 
                else: # shared
                    param_strings.append(global_name)
            
            comp_constants_str = ", ".join(param_strings)
            current_block_lines.append(f"{indent}{comp_accessor} = {template_name}({comp_constants_str});")
            
            for local_name in template_chars["input"].keys():
                mapping = config["mappings"]["input"][local_name]
                global_name = mapping["maps_to"]
                behavior = mapping["among_copies"]
                
                wiring_target = global_name
                if behavior == "duplicated":
                    wiring_target += idx_suffix_for_wiring
                
                current_block_lines.append(f"{indent}{comp_accessor}.{local_name} <== {wiring_target};")
            
            for local_name in template_chars["output"].keys():
                global_out_name = f"{local_name}_{template_name}"
                output_accessor = f"{global_out_name}{idx_suffix_for_wiring}"
                current_block_lines.append(f"{indent}{output_accessor} <== {comp_accessor}.{local_name};")

            current_block_lines.extend(loop_footers)
            instantiation_blocks.append("\n".join(current_block_lines))

        # Step 2: Assemble code
        name = "_".join(merged_name_parts)

        input_decls = sorted(global_input_decls.values())
        output_decls = sorted(list(set(output_array_decls))) 
        component_decls = sorted(list(set(component_array_decls)))
        
        constants_decls = sorted(list(set(global_constant_decls.keys())))
        constants_str = ", ".join(constants_decls)

        code = f"{self.params['circuit_header']}\n\n"
        code += "\n".join(sorted(list(includes))) + "\n\n"
        code += f"template {name}({constants_str})"+"{\n"
        code += "\n".join(input_decls) + "\n\n"
        code += "\n".join(output_decls) + "\n\n"
        code += "\n".join(component_decls) + "\n\n"
        code += "\n\n".join(instantiation_blocks) + "\n"
        code += "}\n"

        file_name = f"{name}.circom"
        with open(file_name, "w") as f:
            f.write(code)

        return file_name
    
    def instantiate_circuit(self, circuit, input, constants):
        template = circuit.template
        # circuit.set_input(input)
        # circuit.set_constants(constants)

        template_characteristics = self.parse_template(template)
        name = template_characteristics["name"]

        missing = [c for c in template_characteristics["constants"] if c not in constants]
        if missing:
            raise ValueError(f"Missing parameter values for: {missing}")
        
        constants_str = ", ".join(Circom_Language_Utils.stringify_constants_array(constants[c]) for c in template_characteristics["constants"])
        
        code = f"{self.params['circuit_header']}\n\n"
        code += f'include "{template}";\n\n'
        code += f"component main = {name}({constants_str});\n"
        
        file_name = f"{name}_instantiated.circom"
        with open(file_name, "w") as circuit_file:
            circuit_file.write(code)

        instantiated_circuit_params = {
            "template": file_name,
            "constants": constants,
            "input": input
        }

        return Circuit(instantiated_circuit_params)
    
    def parse_template(self, template):
        """
        Extract metadata from a Circom template file.
        """
        with open(template, "r") as f:
            text = f.read()

        # Match `template Name(param1, param2, ...) {`
        header_pattern = r"template\s+(\w+)\s*\(([^)]*)\)\s*\{"
        header_match = re.search(header_pattern, text)
        if not header_match:
            raise ValueError(f"No Circom template found in {template}")

        name = header_match.group(1)
        raw_params = header_match.group(2).strip()
        constants = [p.strip() for p in raw_params.split(",") if p.strip()] if raw_params else []

        # Match all input and output signal declarations
        # This regex captures:
        # 1: "input" or "output"
        # 2: signal name (e.g., "x")
        # 3: (Optional) signal dimensions (e.g., "[alpha][10]")
        # signal_pattern = r"signal\s+(input|output)\s+([\w]+)\s*([^;{]*)"

        # This new pattern explicitly matches:
        # 1. (input|output) signal ...
        # 2. (input|output) TypeName() ...
        # 3. signal (input|output) ...
        # 4. TypeName() (input|output) ...
        #
        # Group Analysis:
        # g1: (input|output)       (from Alt 1/2)
        # g2: (signal|[\w]+\(\))   (Type, from Alt 1/2)
        # g3: (signal|[\w]+\(\))   (Type, from Alt 3/4)
        # g4: (input|output)       (from Alt 3/4)
        # g5: ([\w]+)              (Name)
        # g6: ([^;{]*)             (Dims)
        signal_pattern = r"\s*(?:(input|output)\s+(signal|[\w]+\(\))|(signal|[\w]+\(\))\s+(input|output))\s+([\w]+)\s*([^;{]*)"
        
        inputs = {}  # e.g., {"x": "[alpha][10]", "z": "[2][3][2]"}
        outputs = {} # e.g., {"o": ""}

        for match in re.finditer(signal_pattern, text):
            # Extract groups. Some will be None depending on which alternative matched.
            g1, g2, g3, g4, g5, g6 = match.groups()
            
            sig_direction = g1 or g4  # This will be 'input' or 'output'
            sig_type_keyword = g2 or g3 # This is 'signal' or 'TE_point()'. We don't use this, but it's here.
            sig_name = g5             # This will be 'x' or 'my_point'
            sig_dims = g6             # This will be '[2]' or ''

            # Clean up dimensions string: remove whitespace and trailing ';'
            sig_dims = sig_dims.strip().replace(" ", "").replace(";", "")

            sig_characteristic = {
                    "dims": sig_dims,
                    "type": sig_type_keyword
            }
            
            if sig_direction == "input":
                inputs[sig_name] = sig_characteristic
            else:
                outputs[sig_name] = sig_characteristic

        return {
            "name": name,
            "constants": constants,
            "input": inputs,
            "output": outputs
        }
    
    @classmethod
    def stringify_constants_array(cls, constants_array):
        """
        Used to remove extra quotes from arrays.
        E.g., ["0", "1"] -> "[0,1]"
        """

        if isinstance(constants_array, list):
            constants = [Circom_Language_Utils.stringify_constants_array(c) for c in constants_array]
            return f"[{','.join(constants)}]"
        elif isinstance(constants_array, str):
            return constants_array
        else:
            return str(constants_array)