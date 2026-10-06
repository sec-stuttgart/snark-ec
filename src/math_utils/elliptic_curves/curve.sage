from scripts.sageImport import sage_import
from typing import Type
import json
from proving_pipeline.circuit_wrapper.circuit_format import Circuit_Format
from scripts.JSON import JSONUtils

class CurvePoint(Circuit_Format):
    def __init__(self, curve_params=None, name=None):
        self.name = name
        self.curve_params = curve_params

        if self.curve_params:
            self.init_curve()

    def init_curve(self):
        self.base_field = GF(self.curve_params["base_field"])
        self.order = self.curve_params["order"]
        self.cofactor = self.base_field(self.curve_params["cofactor"])
        self.subgroup_order = Integer(self.order) // Integer(self.cofactor)
    
    def __add__(self, other):
        """
        Used to execute the group law
        """
        selfSW = self.castTo("ShortWeierstrassPoint")
        otherSW = other.castTo("ShortWeierstrassPoint")

        resultSW = selfSW + otherSW

        return self.castFrom(resultSW)

    def __mul__(self, multiplier):
        """
        Scalar multiplication
        """
        resultSW = multiplier * self.castTo("ShortWeierstrassPoint")
        return self.castFrom(resultSW)

    def __rmul__(self, multiplier):
        return self.__mul__(multiplier)

    def __inv__(self):
        """
        Calculate inverse in group
        """
        resultSW = -self.castTo("ShortWeierstrassPoint")
        return self.castFrom(resultSW)
    
    def discreteLog(self, base_point):
        """
        Used to find the multiplicator m where m*basePoint = self
        """
        selfSW = self.castTo("ShortWeierstrassPoint")
        base_pointSW = base_point.castTo("ShortWeierstrassPoint")
        return selfSW.discreteLog(base_pointSW)

    def gen_powers(self, base, digits):
        """
        Generates an array 
        [   
           [e, 1*self, 2*1*self,\dots, (b-1)*1*self],
           [e, b*self, 2*b*self,\dots, (b-1)*b*self],
           [e, (b^2)*self, 2*(b^2)*self,\dots, (b-1)*(b^2)*self],
           \dots,
           [e, (b^{l-1})*self, 2*(b^{l-1})*self,\dots, (b-1)*(b^{n-1})*self]
        ]
        Where b is the base used.
        """
        powers = []
        for i in range(0, digits):
            multiple_self = self * (base**i)
            powers_i = []
            for j in range(0, base):
                powers_i.append(multiple_self*j)
            powers.append(powers_i)
        return powers

    def generate_optimized_powers_for_M_SW(self, base, digits):
        powers = []

        # Index 0 .. digits-4: With offset 1
        for d in range(digits-3):
            digit_powers = []
            for i in range(base):
                scalar = i*base**d + 1
                digit_powers.append(self*scalar)
            powers.append(digit_powers)

        # Index digits - 3: With special offset base^{digits-3} + (base - (digits - 3) mod base)
        digit_powers = []
        for i in range(base):
            scalar = i*base**(digits-3) + base**(digits-3) + ((base - (digits - 3)) % base)
            digit_powers.append(self*scalar)
            # print(f"Digit: {digits-3}, Value: {i}, Scalar: {scalar}")
        powers.append(digit_powers)

        # Index digits - 2: With special offset base
        digit_powers = []
        for i in range(base):
            scalar = i*base**(digits-2) + base
            digit_powers.append(self*scalar)
        powers.append(digit_powers)

        # Index digits - 1: To remove added offsets: -base^{digits-3} - (digits-3) - base - (base - (digits - 3) mod base)
        digit_powers = []
        for i in range(base):
            scalar = (i*base**(digits-1) - base**(digits-3) - (digits-3) - base - ((base - (digits - 3)) % base)) % Integer(self.subgroup_order)
            digit_powers.append(self*scalar)
        powers.append(digit_powers)

        return powers

    @classmethod
    def getInfinity(cls, curveParams, name=None):
        raise NotImplementedError("Behaviour needs to be implemented in specific subclass.")

    def serialize(self):
        state = super().serialize()
        state["curve"] = self.curve_params
        if self.name:
            state["name"] = self.name
        return state

    def deserialize(self, state):
        super().deserialize(state)
        self.curve_params = state["curve"]
        self.init_curve()
        if state.get("name"):
            self.name = state["name"]
        
    def castTo(self, cls: Type):
        """
        Cast self to the type specified by cls
        """
        raise NotImplementedError("Behaviour needs to be implemented in specific subclass.")

    def castFrom(self, other):
        """
        Cast other to the same type as self
        """
        raise NotImplementedError("Behaviour needs to be implemented in specific subclass.")

    def toJSON(self):
        raise NotImplementedError("Behaviour needs to be implemented in specific subclass.")

    def __str__(self):
        return str(self.toJSON())

    def getGenerator(self, name=None):
        """
        Generates a random generator of the elliptic curve subgroup (If this subgroup has prime order.)
        """
        pointSW = self.castTo("ShortWeierstrassPoint")
        return self.castFrom(pointSW.getGenerator(name=name))

    def getRandomPoint(self, name=None):
        """
        Generates a random point in the elliptic curve subgroup (not infty)
        """
        pointSW = self.castTo("ShortWeierstrassPoint")
        return self.castFrom(pointSW.getGenerator(name=name))

    def castTo(self, clsString: Type):
        if clsString == "ShortWeierstrassPoint":
            return self.castToShortWeierstrassPoint()
        elif clclsStrings == "MontgomeryProjectivePoint":
            return self.castToMontgomeryProjectivePoint()
        elif clsString == "MontgomeryAffinePoint":
            return self.castToMontgomeryAffinePoint()
        elif clsString == "TwistedEdwardsPoint":
            return self.castToTwistedEdwardsPoint()
        else:
            raise NotImplementedError(f"Conversion from {str(type(self))} to {str(cls)} not implemented.")

    def castFrom(self, other):
        typeName = type(other).__name__  # Get class name as a string
        if typeName == "ShortWeierstrassPoint":
            return self.castFromShortWeierstrassPoint(other)
        elif typeName == "MontgomeryProjectivePoint":
            return self.castFromMontgomeryProjectivePoint(other)
        elif typeName == "MontgomeryAffinePoint":
            return self.castFromMontgomeryAffinePoint(other)
        elif typeName == "TwistedEdwardsPoint":
            return self.castFromTwistedEdwardsPoint(other)
        else:
            raise NotImplementedError(f"Conversion from {typeName} to {type(self).__name__} not implemented.")

    def castToShortWeierstrassPoint(self):
        raise NotImplementedError("Behaviour needs to be implemented in specific subclass.")

    def castToMontgomeryProjectivePoint(self):
        raise NotImplementedError("Behaviour needs to be implemented in specific subclass.")

    def castToMontgomeryAffinePoint(self):
        raise NotImplementedError("Behaviour needs to be implemented in specific subclass.")

    def castToTwistedEdwardsPoint(self):
        raise NotImplementedError("Behaviour needs to be implemented in specific subclass.")


    def castFromShortWeierstrassPoint(self, other):
        raise NotImplementedError("Behaviour needs to be implemented in specific subclass.")

    def castFromMontgomeryProjectivePoint(self, other):
        raise NotImplementedError("Behaviour needs to be implemented in specific subclass.")

    def castFromMontgomeryAffinePoint(self, other):
        raise NotImplementedError("Behaviour needs to be implemented in specific subclass.")

    def castFromTwistedEdwardsPoint(self, other):
        raise NotImplementedError("Behaviour needs to be implemented in specific subclass.")
