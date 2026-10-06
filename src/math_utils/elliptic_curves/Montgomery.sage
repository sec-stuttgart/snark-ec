from scripts.sageImport import sage_import
from typing import Type
import json
from scripts.JSON import JSONUtils
sage_import('math_utils/elliptic_curves/curve', fromlist=['CurvePoint'])
sage_import('math_utils/elliptic_curves/ShortWeierstrass', fromlist=['ShortWeierstrassPoint'])

class MontgomeryPoint(CurvePoint):
    def __init__(self, curve_params=None, name=None):
        super().__init__(curve_params, name=name)
        if self.curve_params:
            self.A = self.base_field(curve_params["M_A"])
            self.B = self.base_field(curve_params["M_B"])

    def serialize(self):
        state = super().serialize()
        return state

    def deserialize(self, state):
        super().deserialize(state)
        coordinates = state["coordinates"]

        self.A = self.base_field(self.curve_params["M_A"])
        self.B = self.base_field(self.curve_params["M_B"])

    def castFromShortWeierstrassParameters(self, other):
        # According to MoonMathManual, Section 5.2
        # Weierstrass to Montgomery: E_{a,b} -> M_{A, B}
        # Define the cubic equation z^3 + az + b = 0 and find roots
        R.<z> = PolynomialRing(self.base_field)
        cubic = z^3 + other.a*z + other.b
        roots = cubic.roots()

        # Ensure the cubic equation has at least one root
        if not roots:
            raise ValueError("The cubic equation z^3 + az + b = 0 has no roots in F.")

        # Pick the first root alpha (or choose based on your application)
        alpha = roots[0][0]

        # Check if 3*alpha^2 + a is a quadratic residue
        quad_residue = 3*alpha^2 + other.a
        if not quad_residue.is_square():
            raise ValueError("3*alpha^2 + a is not a quadratic residue in F.")

        # Compute s = 1 / sqrt(3*alpha^2 + a)
        s = 1 / quad_residue.sqrt()

        A = 3*alpha*s
        B = s
        M_curve_params = self.curve_params
        M_curve_params["M_A"] = A
        M_curve_params["M_B"] = B
        return M_curve_params, alpha, s

    def castToShortWeierstrassParameters(self):
        # Parameters (calculated from montgomery equation) (according to MoonMathManual, 
        # 5.2 Montgomery curves):
        a = (self.base_field(3)-self.A**2)/(self.base_field(3)*self.B**2)
        b = (self.base_field(2)*self.A**3-self.base_field(9)*self.A)/(self.base_field(27)*self.B**3)
        SW_curve_params = self.curve_params
        SW_curve_params["SW_a"] = a
        SW_curve_params["SW_b"] = b
        return SW_curve_params

class MontgomeryAffinePoint(MontgomeryPoint):
    def __init__(self, x=None, y=None, not_infinity=None, curve_params=None, name=None):
        super().__init__(curve_params, name=name)
        if self.curve_params:
            if x and y and not_infinity:
                self.x = self.base_field(x)
                self.y = self.base_field(y)
                self.not_infinity = not_infinity
            else: # Just use infinity
                self.x = self.base_field(0)
                self.y = self.base_field(0)
                self.not_infinity = False

    @classmethod
    def getInfinity(cls, curve_params, name=None):
        return MontgomeryAffinePoint(0, 0, False, curve_params, name=name)

    def serialize(self):
        state = super().serialize()
        state["coordinates"] = {
            "x": str(self.x),
            "y": str(self.y),
            "notInfty": str(self.not_infinity)
        }
        return state

    def deserialize(self, state):
        super().deserialize(state)
        coordinates = state["coordinates"]

        self.x = self.base_field(coordinates["x"])
        self.y = self.base_field(coordinates["y"])
        self.not_infinity = (coordinates["notInfty"].strip().lower() == "true" or int(coordinates["notInfty"]) == 1)

    def to_constants_format(self):
        return [str(self.x), str(self.y), str(int(self.not_infinity))]

    def to_input_format(self):
        return {
            "x": str(self.x),
            "y": str(self.y),
            "notInfty": str(int(self.not_infinity))  # Convert boolean to 1 or 0 string
        }
    
    def castToShortWeierstrassPoint(self):
        """
        Map a point from Montgomery form to Weierstrass form. (MoonMathManual, Section 5.2)
        """
        SW_curve_params = self.castToShortWeierstrassParameters()
        if self.not_infinity:
            return ShortWeierstrassPoint(self.x/self.B + self.A/(3*self.B), self.y/self.B, True, SW_curve_params, name=self.name)
        else:
            return ShortWeierstrassPoint(0, 0, False, SW_curve_params, name=self.name) # Infinity

    def castToMontgomeryProjectivePoint(self):
        raise NotImplementedError("Behaviour needs to be implemented in specific subclass.")

    def castToTwistedEdwardsPoint(self):
        raise NotImplementedError("Behaviour needs to be implemented in specific subclass.")


    def castFromShortWeierstrassPoint(self, other):
        """
        Map a point from Weierstrass form to Montgomery form. (MoonMathManual, Section 5.2)
        """
        M_curve_params, alpha, s = self.castFromShortWeierstrassParameters(other)
        otherM = None
        if other.toSage() != other.sage_curve(0): # Not infinity
            return MontgomeryAffinePoint(s * (other.x - alpha), s * other.y, True, M_curve_params, name=other.name)
        else:
            return MontgomeryAffinePoint(0, 0, False, M_curve_params, name=other.name)

    def castFromMontgomeryProjectivePoint(self, other):
        raise NotImplementedError("Behaviour needs to be implemented in specific subclass.")

    def castFromTwistedEdwardsPoint(self, other):
        raise NotImplementedError("Behaviour needs to be implemented in specific subclass.")


class MontgomeryProjectivePoint(MontgomeryPoint):
    def __init__(self, X=None, Y=None, Z=None, curve_params=None, name=None):
        super().__init__(curve_params, name=name)
        if self.curve_params:
            if X and Y and Z:
                self.X = self.base_field(X)
                self.Y = self.base_field(Y)
                self.Z = self.base_field(Z)

    @classmethod
    def getInfinity(cls, curve_params, name=None):
        return MontgomeryProjectivePoint(0, 1, 0, curve_params, name=name)

    def serialize(self):
        state = super().serialize()
        state["coordinates"] = {
            "X": str(self.X),
            "Y": str(self.Y),
            "Z": str(self.Z),
        }
        return state

    def deserialize(self, state):
        super().deserialize(state)
        coordinates = state["coordinates"]

        self.X = self.base_field(coordinates["X"])
        self.Y = self.base_field(coordinates["Y"])
        self.Z = self.base_field(coordinates["Z"])
    
    def to_constants_format(self):
        return [str(self.X), str(self.Y), str(self.Z)]

    def to_input_format(self):
        return {
            "X": str(self.X),
            "Y": str(self.Y),
            "Z": str(self.Z)
        }

    def castToShortWeierstrassPoint(self):
        selfAffine = self.castToMontgomeryAffinePoint()
        return selfAffine.castToShortWeierstrassPoint()

    def castToMontgomeryAffinePoint(self):
        if self.Z != 0:  # Not infinity
            return MontgomeryAffinePoint(self.X, self.Y, True, self.curve_params, name=self.name)
        else:
            return MontgomeryAffinePoint(0, 0, False, self.curve_params, name=self.name)

    def castToTwistedEdwardsPoint(self):
        raise NotImplementedError("Behaviour needs to be implemented in specific subclass.")


    def castFromShortWeierstrassPoint(self, other):
        otherAffine = self.castToMontgomeryAffinePoint().castFromShortWeierstrassPoint(other)
        return self.castFromMontgomeryAffinePoint(otherAffine)

    def castFromMontgomeryAffinePoint(self, other):
        if other.not_infinity:
            return MontgomeryProjectivePoint(other.x, other.y, 1, self.curve_params, name=other.name)
        else:
            return MontgomeryProjectivePoint(0, 1, 0, self.curve_params, name=other.name)

    def castFromTwistedEdwardsPoint(self, other):
        raise NotImplementedError("Behaviour needs to be implemented in specific subclass.")

