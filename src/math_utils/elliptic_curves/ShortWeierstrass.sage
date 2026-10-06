from scripts.sageImport import sage_import
from typing import Type
from scripts.JSON import JSONUtils
sage_import('math_utils/constants', fromlist=['PLAINTEXT_LIMIT'])
sage_import('math_utils/elliptic_curves/curve', fromlist=['CurvePoint'])

class ShortWeierstrassPoint(CurvePoint):
    def __init__(self, x=None, y=None, not_infinity=None, curve_params=None, name=None):
        super().__init__(curve_params, name)
        if self.curve_params:
            self.a = self.base_field(self.curve_params["SW_a"])
            self.b = self.base_field(self.curve_params["SW_b"])
            self.sage_curve = EllipticCurve(self.base_field, [self.a, self.b])

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
        return ShortWeierstrassPoint(0, 0, False, curve_params, name=name)

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

        self.a = self.base_field(self.curve_params["SW_a"])
        self.b = self.base_field(self.curve_params["SW_b"])

        self.x = self.base_field(coordinates["x"])
        self.y = self.base_field(coordinates["y"])
        self.not_infinity = (coordinates["notInfty"].strip().lower() == "true" or int(coordinates["notInfty"]) == 1)

        self.sage_curve = EllipticCurve(self.base_field, [self.a, self.b])

    def to_constants_format(self):
        return [str(self.x), str(self.y), str(int(self.not_infinity))]

    def to_input_format(self):
        return {
            "x": str(self.x),
            "y": str(self.y),
            "notInfty": str(int(self.not_infinity))  # Convert boolean to 1 or 0 string
        }

    def toSage(self):
        """
        Convert to representation with preimplemented sage elliptic curve
        """
        if self.not_infinity:
            return self.sage_curve(self.x, self.y)
        else:
            # print(f"Point at infinity: {self.sage_curve}")
            return self.sage_curve(0)

    def fromSage(self, point, name=None):
        """
        Convert from representation with preimplemented sage elliptic curve to this class
        """
        # print(f"Point is {point}")
        if point: # Point is not infinity
            return ShortWeierstrassPoint(point[0], point[1], True, self.curve_params, name=name)
        else:
            return ShortWeierstrassPoint(0, 0, False, self.curve_params, name=name)


    def isCompatible(self, other):
        return self.a == other.a and self.b == other.b

    def __add__(self, other):
        """
        Used to execute the group law
        """
        if self.isCompatible(other):
            resultSage = self.toSage() + other.toSage()
            return self.fromSage(resultSage)
        else:
            raise ValueError("Points are not from the same curve.")

    def __mul__(self, multiplier):
        """
        Scalar multiplication
        """
        resultSage = Integer(multiplier) * self.toSage()
        # print(f"Multiplier: {multiplier}, self sage point: {self.toSage()}, Mul result: {resultSage}")
        tmp = self.fromSage(resultSage)
        return self.fromSage(resultSage)

    def __rmul__(self, multiplier):
        return self.__mul__(multiplier)

    def __inv__(self):
        """
        Calculate inverse in group
        """
        resultSage = -self.toSage()
        return self.fromSage(resultSage)
    
    def discreteLog(self, basePoint):
        """
        Used to find the multiplicator m where m*basePoint = self
        """
        if self.isCompatible(other):
            selfSage = self.toSage()
            basePointSage = basePoint.toSage()
            multiplier = 0
            while multiplier*basePointSage != selfSage and multiplier <= PLAINTEXT_LIMIT:
                multiplier += 1
            if multiplier*basePointSW == pointSW:
                return multiplier
            raise ArithmeticError(f"This point is not a multiple within the allowed range [0, {PLAINTEXT_LIMIT}] of the given basePoint.")
        else:
            raise ValueError("Point and basepoint are not from the same curve.")

    def getGenerator(self, name=None):
        """
        Generates a random generator of the elliptic curve subgroup (If this subgroup has prime order.)
        """
        point = None
        while point == None or not point.not_infinity:
            point = self.getRandomPoint(name)
        return point

    def getRandomPoint(self, name=None):
        """
        Generates a random point in the elliptic curve subgroup (not infty)
        """
        pointSage = self.sage_curve.random_point()
        point = self.fromSage(pointSage)
        point = point.cofactorClearing()
        point.name = name
        return point

    def cofactorClearing(self):
        """
        Computes point * (cofactor)
        If this is not infty (neutral element), the point is a generator of the subgroup. Otherwise, it is not a generator of the subgroup.
        """
        return self * (self.cofactor)