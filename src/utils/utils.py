import sys
import subprocess
import importlib.util
import os
import random
import shutil

class Utils:
    @classmethod
    def execute_shell_command(cls, command):
        result = subprocess.run(command, shell=True, capture_output=True, text=True)
        print(result.stdout)
        if result.returncode != 0:
            raise RuntimeError(f"ERROR executing command: {command}.")

        return result.stdout
    
    @classmethod
    def create_class_reference(cls, module_name, class_name):
        file_path = str(module_name).replace(".", "/")
        file_path_py = file_path + ".py"
        file_path_sage = file_path + ".sage"
        module = None

        if os.path.exists(file_path_py):
            # Dynamically import the module
            module = importlib.import_module(module_name)
        elif os.path.exists(file_path_sage):
            # 1. Use --preparse to generate the .sage.py file
            Utils.execute_shell_command(f"sage --preparse {file_path_sage}")
            
            # 2. Rename the generated file so importlib can find it normally
            filepath_preparsed_file = os.path.join(file_path + ".sage.py")
            # print(f"Preparsed file: {filepath_preparsed_file}")
            
            if os.path.exists(filepath_preparsed_file):
                shutil.move(filepath_preparsed_file, file_path_py)
            else:
                raise FileNotFoundError(f"Failed to preparse {file_path_sage}")
            
            module = importlib.import_module(module_name)
        else:
            raise FileNotFoundError(f"No .py or .sage file for module {module_name} detected")

        # Get the class reference from the module
        cls = getattr(module, class_name)

        return cls
    
    @classmethod
    def create_class_reference_from_config(cls, config):
        # print(f"Config: {config}")
        module_name = config["module_name"]
        class_name = config["class_name"]
        return Utils.create_class_reference(module_name, class_name)
    
    @classmethod
    def create_empty_instance_of_class(cls, module_name, class_name):
        cl = Utils.create_class_reference(module_name, class_name)
        return cl()
    
    @classmethod
    def create_empty_instance_of_class_from_config(cls, config):
        cl = Utils.create_class_reference_from_config(config)
        return cl()

    @classmethod
    def create_instance_of_class(cls, module_name, class_name, params):
        cl = Utils.create_class_reference(module_name, class_name)
        return cl(params)
    
    @classmethod
    def create_instance_of_class_from_config(cls, config):
        cl = Utils.create_class_reference_from_config(config)
        params = config["params"]
        return cl(params)
    
    @classmethod
    def deserialize_from_state(cls, state):
        instance = Utils.create_empty_instance_of_class_from_config(state)
        if hasattr(instance, "deserialize"):
            method = getattr(instance, "deserialize")
            method(state)
            return instance
        else:
            raise ModuleNotFoundError(f"The class {instance.__class__.__name__} in module {instance.__class__.__module__} does not have a method deserialize.")

    @classmethod
    def genRandomnessLike(cls, array, max_value, min_value=0):
        """
        Generates an array with the same shape as the input array, filled with random numbers.
        """
        if isinstance(array, list):
            return [Utils.genRandomnessLike(subarray, max_value, min_value) for subarray in array]
        else:
            return random.randint(min_value, max_value)
        
    @classmethod
    def delete_differences(cls, directory_path, old_directory_contents, exceptions):
        """
        Removes all files and subdirectories which are present in the directory given by directory_path that are not present in the old_directory_contents. 
        Files/ directories in exceptions are not removed
        """
        current_contents = set(os.listdir(directory_path))
        old_contents_set = set(old_directory_contents)
        
        # Identify items created during this run
        new_items = current_contents - old_contents_set
        
        # Normalize paths for accurate comparison
        abs_root = os.path.abspath(directory_path)
        abs_exceptions = [os.path.abspath(e) for e in exceptions]

        for item in new_items:
            abs_item_path = os.path.join(abs_root, item)
            should_preserve = False

            # Check if this item is an exception OR contains an exception
            # (e.g., if we want to save 'results/file.json', we must not delete the 'results' folder)
            for exc in abs_exceptions:
                # 1. Exact match
                if abs_item_path == exc:
                    should_preserve = True
                    break
                
                # 2. Parent check: Is the item a parent of the exception?
                # We use commonpath to see if the item path is the prefix of the exception path
                try:
                    if os.path.commonpath([abs_item_path, exc]) == abs_item_path:
                        should_preserve = True
                        break
                except ValueError:
                    # Paths might be on different drives or mix relative/absolute in a way commonpath dislikes
                    continue

            if should_preserve:
                continue

            # Delete the item
            try:
                if os.path.isdir(abs_item_path):
                    shutil.rmtree(abs_item_path)
                    # print(f"Deleted directory: {item}")
                else:
                    os.remove(abs_item_path)
                    # print(f"Deleted file: {item}")
            except Exception as e:
                print(f"Failed to delete {item}: {e}")

        