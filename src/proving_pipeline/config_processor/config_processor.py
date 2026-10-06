import sys
import os
from scripts.JSON import JSONUtils

class Config_Processor:
    @staticmethod 
    def load_meta_config(meta_config_path):
        """
        Loads a meta-config file (list of paths/dicts).
        """
        try:
            meta_config_items = JSONUtils.load_file(meta_config_path)
            if not isinstance(meta_config_items, list):
                print(f"Error: {meta_config_path} must contain a list (of paths or objects).")
                sys.exit(1)
        except Exception as e:
            print(f"Failed to load meta-config {meta_config_path}: {e}")
            sys.exit(1)
        return meta_config_items

    @staticmethod 
    def merge_meta_config(meta_config_items, base_config={}):
        """
        Merges items in a meta config (list of paths/dicts) sequentially
        into the base_config using JSONUtils.safe_merge_configs.
        """
        # 1. Start with the base config
        config = base_config.copy()
        print(f"Processing configuration items from {meta_config_items}...")

        # 2. Iterate and Merge
        for index, item in enumerate(meta_config_items):
            try:
                current_config = {}
                
                # Case A: Item is a file path (String)
                if isinstance(item, str):
                    print(f" -> Merging file: {item}")
                    if not os.path.exists(item):
                        print(f"Error: Configuration file not found: {item}")
                        sys.exit(1)
                    current_config = JSONUtils.load_file(item)
                    
                # Case B: Item is a direct configuration (Dictionary)
                elif isinstance(item, dict):
                    print(f" -> Merging inline configuration object (Index {index})")
                    current_config = item
                    
                else:
                    print(f"Error: Item at index {index} is neither a file path nor a dictionary.")
                    sys.exit(1)

                # Apply the safe merge
                config = JSONUtils.safe_merge_configs(config, current_config)
                
            except Exception as e:
                print(f"Failed to merge item at index {index}: {e}")
                sys.exit(1)
        
        print("Configuration merge successful.")
        return config

    @staticmethod
    def load_and_merge_meta_config(meta_config_path, base_config={}):
        """
        Loads a meta-config file (list of paths/dicts) and merges them sequentially
        into the base_config using JSONUtils.safe_merge_configs.
        """
        meta_config_items = Config_Processor.load_meta_config(meta_config_path)
        return Config_Processor.merge_meta_config(meta_config_items, base_config=base_config)

        # 1. Load the meta-config list
        try:
            meta_config_items = JSONUtils.load_file(meta_config_path)
            if not isinstance(meta_config_items, list):
                print(f"Error: {meta_config_path} must contain a list (of paths or objects).")
                sys.exit(1)
        except Exception as e:
            print(f"Failed to load meta-config {meta_config_path}: {e}")
            sys.exit(1)

        # 2. Start with the base config
        config = base_config.copy()
        print(f"Processing configuration items from {meta_config_path}...")

        # 3. Iterate and Merge
        for index, item in enumerate(meta_config_items):
            try:
                current_config = {}
                
                # Case A: Item is a file path (String)
                if isinstance(item, str):
                    print(f" -> Merging file: {item}")
                    if not os.path.exists(item):
                        print(f"Error: Configuration file not found: {item}")
                        sys.exit(1)
                    current_config = JSONUtils.load_file(item)
                    
                # Case B: Item is a direct configuration (Dictionary)
                elif isinstance(item, dict):
                    print(f" -> Merging inline configuration object (Index {index})")
                    current_config = item
                    
                else:
                    print(f"Error: Item at index {index} is neither a file path nor a dictionary.")
                    sys.exit(1)

                # Apply the safe merge
                config = JSONUtils.safe_merge_configs(config, current_config)
                
            except Exception as e:
                print(f"Failed to merge item at index {index}: {e}")
                sys.exit(1)
        
        print("Configuration merge successful.")
        return config
    
