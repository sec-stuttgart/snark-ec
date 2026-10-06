import json
import os
import sys

class JSONUtils():
    def toJSON(obj, innerData, name=None):
        data = None
        if name != None:
            data = {
                name: innerData
            }
        elif obj.name != None:
            data = {
                obj.name: innerData
            }
        else:
            data = innerData
            
        return data

    def arrayToJSON(data):
        if isinstance(data, list):
            return [JSONUtils.arrayToJSON(subdata) for subdata in data]
        elif hasattr(data, 'toJSON') and callable(getattr(data, 'toJSON')):
            try:
                return data.toJSON()
            except Exception as e:
                print(f"Error serializing {data}: {e}")
        else:
            # print(str(data))
            return str(data)
    
    def jsonToArray(data):
        if isinstance(data, dict):
            return JSONUtils.jsonToArray(list(data.values()))
        elif isinstance(data, list):
            return [JSONUtils.jsonToArray(d) for d in data]
        else:
            return data

    def combine(dataArray):
        combinedData = {}
        for data in dataArray:
            if isinstance(data, dict):
                jsonData = data
            elif hasattr(data, 'toJSON') and callable(getattr(data, 'toJSON')):
                try:
                    # jsonData = json.loads(data.toJSON())
                    jsonData = data.toJSON()
                except Exception as e:
                    print(f"Error serializing {data}: {e}")
                    continue
            else:
                print(f"Skipping unsupported type: {type(data)}")
                continue
            combinedData = combinedData | jsonData
        return combinedData
    
    def stringify_json(json_data):
        """
        Converts all values in the json dictionary to strings.
        """
        stringified_json_data = {}
        if isinstance(json_data, dict):
            for key, value in json_data.items():
                stringified_json_data[key] = JSONUtils.stringify_json(value)
        elif isinstance(json_data, list):
            try:
                stringified_json_data = [JSONUtils.stringify_json(v) for v in json_data]
            except NotImplementedError as e:
                stringified_json_data = str(json_data)
        else:
            stringified_json_data = str(json_data)
        return stringified_json_data
    
    @classmethod
    def destringify_json(cls, obj):
        """
        Recursively traverses a dictionary or list and converts 
        stringified booleans and integers back to their native Python types.
        """
        if isinstance(obj, dict):
            return {k: cls.destringify_json(v) for k, v in obj.items()}
        elif isinstance(obj, list):
            return [cls.destringify_json(v) for v in obj]
        elif isinstance(obj, str):
            clean_str = obj.strip()
            lower_str = clean_str.lower()
            
            # 1. Check for booleans
            if lower_str == 'true':
                return True
            elif lower_str == 'false':
                return False
            
            # 2. Check for integers
            try:
                # This safely catches both "42" and "-42"
                return int(clean_str)
            except ValueError:
                try:
                    return float(clean_str)
                except ValueError:
                    # If it throws a ValueError, it's just a normal string
                    pass
                
        # Return the object unchanged if it doesn't match the above
        return obj

    def exportToJSON(jsonData, filepath=None):
        jsonData = JSONUtils.stringify_json(jsonData)
        if filepath == None: # Write to CMD
            print(json.dumps(jsonData, indent=4))
        else: # Write to file
            # Ensure the directory exists
            directory = os.path.dirname(filepath)
            if directory and not os.path.exists(directory):
                os.makedirs(directory)

            # Write to a JSON file
            with open(filepath, 'w') as f:
                json.dump(jsonData, f, indent=4)

    def combineAndExport(jsonDataArray, filePath=None):
        JSONUtils.exportToJSON(JSONUtils.combine(jsonDataArray), filePath)

    def load_file(json_file):
        with open(json_file) as f:
            d = json.load(f)
            return d

    def save_file(json_data, file_path):
        # print(f"Data to save: {json.dumps(json_data, indent=4)}")
        stringified_data = JSONUtils.stringify_json(json_data)
        with open(file_path, 'w') as f:
            json.dump(stringified_data, f, indent=4)
        
    def merge_json_dicts(json_dicts):
        """
        Merge a list of dictionaries strictly:
        - If a key appears in only one dict, take that value.
        - If a key appears in multiple dicts with the same value, keep it.
        - If a key appears in multiple dicts with differing values, raise ValueError.
        """
        merged = {}
        for d in json_dicts:
            for key, value in d.items():
                if key not in merged:
                    merged[key] = value
                else:
                    if merged[key] != value:
                        raise ValueError(f"Conflict for key '{key}': {merged[key]} != {value}")
        return merged
    
    def override_json_dict(old_dict, new_dict):
        """
        Override the values of the old_dict with the values of the new dict. 
        Values that are only in the new_dict are added.
        Values that are not present in the new dict are kept with the values from the old dict.
        """
        for key, value in new_dict.items():
            if isinstance(value, dict) and isinstance(old_dict.get(key), dict):
                old_dict[key] = JSONUtils.override_json_dict(old_dict[key], value)
            else: 
                old_dict[key] = value
        return old_dict
        
    @staticmethod
    def safe_merge_configs(base_dict, new_dict):
        """
        Merges new_dict into base_dict with the following rules:
        - Dictionaries: Merged recursively.
        - Lists: Concatenated.
        - Scalars (Values): Must be unique or identical. Differences trigger a halt.
        """
        for key, value in new_dict.items():
            if key not in base_dict:
                base_dict[key] = value
            else:
                base_value = base_dict[key]

                # 1. Check for Type Mismatch (e.g., merging a list into a dict)
                if not isinstance(value, type(base_value)) and not isinstance(base_value, type(value)):
                    print(f"CONFIG ERROR: Type mismatch for key '{key}'.")
                    print(f"Base type: {type(base_value).__name__}, New type: {type(value).__name__}")
                    sys.exit(1)

                # 2. Recursive Merge for Dictionaries
                if isinstance(value, dict):
                    JSONUtils.safe_merge_configs(base_value, value)

                # 3. Concatenate Lists
                elif isinstance(value, list):
                    # Extend the existing list with the new list
                    base_dict[key] = base_value + value

                # 4. Check for Scalar Conflicts
                else:
                    if base_value != value:
                        print(f"CONFIG ERROR: Conflicting values for key '{key}'.")
                        print(f"Base value: {base_value}")
                        print(f"New value:  {value}")
                        sys.exit(1)
        
        return base_dict
        