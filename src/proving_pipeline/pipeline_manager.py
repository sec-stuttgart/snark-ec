from utils.utils import Utils
from proving_pipeline.circuit_wrapper.circuit import Circuit

class Pipeline_Manager():
    @classmethod
    def get_language_utils(cls, config):
        return Utils.create_instance_of_class_from_config(config)
    
    @classmethod
    def get_circuit_processor(cls, config):
        return Utils.create_instance_of_class_from_config(config)
    
    @classmethod
    def get_prover_backend(cls, config):
        return Utils.create_instance_of_class_from_config(config)