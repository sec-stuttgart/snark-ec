from scripts.sageImport import sage_import
from proving_pipeline.circuit_wrapper.circuit import Circuit
from scripts.JSON import JSONUtils
from utils.utils import Utils
from proving_pipeline.circuit_wrapper.constants import Constants
from proving_pipeline.circuit_wrapper.input import Input
from math_utils.cryptography.encryption.asymmetric.asymmetric_encryption_scheme import Asymmetric_Encryption_Scheme
import json
import random 
import numpy as np
sage_import('utils/sage_utils', fromlist=['Sage_utils'])

class Exponential_Elgamal(Asymmetric_Encryption_Scheme):
    def __init__(self, curve_params=None, name=None):
        super().__init__()
        self.curve_params = curve_params
        if self.curve_params:
            self.init()

    def init(self):
        self.referencePoint = Utils.create_class_reference_from_config(self.curve_params).getInfinity(self.curve_params)
        self.base_field = GF(self.curve_params["base_field"])
        self.generate_priv_key()
        self.generate_pub_key()

    def generate_priv_key(self):
        g = self.referencePoint.getGenerator()
        b = self.base_field.random_element()
        self.priv_key = {
            "g": g,
            "b": b
        }
        self.g = g
        return self.priv_key


    def generate_pub_key(self, priv_key=None):
        key = self.generate_priv_key() if priv_key == None else priv_key
        h = key["g"] * key["b"]
        self.pub_key = {
            "g": key["g"],
            "h": h
        }
        self.h = h
        return self.pub_key

    def encrypt(self, plaintext, pub_key=None, rand=None):
        key = self.pub_key if pub_key == None else pub_key
        r = self.base_field.random_element() if rand == None else rand
        c_0 = key["g"] * r
        c_1 = key["g"] * plaintext + key["h"] * r
        c = {
            "gr": c_0,
            "gplain_hr": c_1
        }
        return c
        
    def decrypt(self, ciphertext, priv_key):
        gplain = (ciphertext["gr"]*priv_key["b"]).__inv__() + ciphertext["gplain_hr"]
        return gplain.discreteLog(priv_key["g"])

    def serialize(self):
        state = super().serialize()
        state["pub_key"] = {
            "g": self.pub_key["g"],
            "h": self.pub_key["h"]
        }
        return state

    def deserialize(self, state):
        super().deserialize(state)
        pb_key_state = state["pub_key"]
        self.pub_key = {
            "g": Utils.deserialize_from_state(pub_key_state["g"]),
            "h": Utils.deserialize_from_state(pub_key_state["h"])
        }
        self.curve_params = self.pub_key["g"].curve_params
        self.referencePoint = self.pub_key["g"]
        self.base_field = GF(self.curve_params["base_field"])