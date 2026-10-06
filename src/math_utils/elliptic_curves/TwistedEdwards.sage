from scripts.sageImport import sage_import
from typing import Type
import json
from scripts.JSON import JSONUtils
sage_import('math_utils/elliptic_curves/curve', fromlist=['CurvePoint'])
sage_import('math_utils/elliptic_curves/ShortWeierstrass', fromlist=['ShortWeierstrassPoint'])
sage_import('math_utils/elliptic_curves/Montgomery', fromlist=['MontgomeryAffinePoint', 'MontgomeryProjectivePoint'])

class TwistedEdwardsPoint(CurvePoint):
    def __init__(self, x=None, y=None, curve_params=None, name=None):
        super().__init__(curve_params, name=name)
        if self.curve_params:
            self.a = self.base_field(self.curve_params["TE_a"])
            self.d = self.base_field(self.curve_params["TE_d"])
            
            if x and y:
                self.x = self.base_field(x)
                self.y = self.base_field(y)
            else: # Just use infinity
                self.x = 0
                self.y = 1

    @classmethod
    def getInfinity(cls, curve_params, name=None):
        # print(f"In TwistedEdwards getInfinity: {json.dumps(curve_params)}")
        return TwistedEdwardsPoint(0, 1, curve_params, name=name)

    def serialize(self):
        state = super().serialize()
        state["coordinates"] = {
            "x": str(self.x),
            "y": str(self.y)
        }
        return state

    def deserialize(self, state):
        super().deserialize(state)
        coordinates = state["coordinates"]

        self.a = self.base_field(self.curve_params["TE_a"])
        self.d = self.base_field(self.curve_params["TE_d"])

        self.x = self.base_field(coordinates["x"])
        self.y = self.base_field(coordinates["y"])

    def to_constants_format(self):
        return [str(self.x), str(self.y)]

    def to_input_format(self):
        return {
            "x": str(self.x),
            "y": str(self.y)
        }
    
    def castToShortWeierstrassPoint(self):
        selfM = self.castToMontgomeryAffinePoint()
        return selfM.castToShortWeierstrassPoint()

    def castToMontgomeryProjectivePoint(self):
        raise NotImplementedError("Behaviour needs to be implemented in specific subclass.")

    def castToMontgomeryAffinePoint(self):
        """
        Map a point from Montgomery form to TwistedEdwards form. (Montgomery curves and their arithmetic, Section 2.5)
        """
        A = 2*((self.a+self.d)/(self.a-self.d))
        B = 4/(self.a-self.d)
        M_curve_params = self.curve_params
        M_curve_params["M_A"] = A
        M_curve_params["M_B"] = B
        if not (self.x == self.base_field(0) and self.y == self.base_field(1)): # Not infinity
            return MontgomeryAffinePoint((1+self.y)/(1-self.y), (1+self.y)/((1-self.y)*self.x), True, M_curve_params, name=self.name)
        else:
            return MontgomeryAffinePoint(0, 0, False, M_curve_params, name=self.name)

    def castFromShortWeierstrassPoint(self, other):
        otherM = self.castToMontgomeryAffinePoint().castFromShortWeierstrassPoint(other)
        return self.castFromMontgomeryAffinePoint(otherM)

    def castFromMontgomeryProjectivePoint(self, other):
        raise NotImplementedError("Behaviour needs to be implemented in specific subclass.")

    def castFromMontgomeryAffinePoint(self, other):
        """
        Map a point from Montgomery form to TwistedEdwards form. (Montgomery curves and their arithmetic, Section 2.5)
        """
        a = (other.A + 2)/other.B
        d = (other.A - 2)/other.B
        TE_curve_params = other.curve_params
        TE_curve_params["TE_a"] = a
        TE_curve_params["TE_d"] = d
        if other.not_infinity:
            return TwistedEdwardsPoint(other.x/other.y, (other.x-1)/(other.x+1), TE_curve_params, name=other.name)
        else: # Infinity
            return TwistedEdwardsPoint(0, 1, TE_curve_params, name=other.name)