pragma circom 2.2.1;

include "../utilities/arithmetic.circom";
include "../utilities/branching.circom";
include "../../../libs/node_modules/circomlib/circuits/comparators.circom";

/**
* Represents a projective point (X:Y:Z).
*/
bus ProjectivePoint() {
    signal X;
    signal Y;
    signal Z;
}

// ========================================================================================================================
//(DE-)SERIALIZING:

template serializeProjective() {
    input ProjectivePoint() in;
    output signal out[3];
    out[0] <== in.X;
    out[1] <== in.Y;
    out[2] <== in.Z;
}

template deserializeProjective() {
    input signal in[3];
    output ProjectivePoint out;
    out.X <== in[0];
    out.Y <== in[1];
    out.Z <== in[2];
}

// ========================================================================================================================
// SPECIAL POINTS:

template inftyProjective() {
    output ProjectivePoint out;
    out.X <== 0;
    out.Y <== 1;
    out.Z <== 0;
}

template isInftyProjective() {
    input ProjectivePoint() in;

    output signal out;

    component isZero = IsZero();
    isZero.in <== in.Z;
    out <== isZero.out;
}

template zeroProjective() {
    output ProjectivePoint() out;

    out.X <== 0;
    out.Y <== 0;
    out.Z <== 1;
}

/**
* Checks whether the given point (X:Y:Z) is (0:0:Z) for some nonzero Z.
*/
template isZeroProjective() {
    input ProjectivePoint() in;

    output signal out;

    component isXZero = IsZero();
    component isYZero = IsZero();
    component isZZero = IsZero();
    isXZero.in <== in.X;
    isYZero.in <== in.Y;
    isZZero.in <== in.Z;
    signal tmp <== isXZero.out * isYZero.out;
    out <== tmp * (1-isZZero.out);
}

// ========================================================================================================================
// NORMALIZATION:

/**
* Normalizes a projective point (X:Y:Z) to
*   - (X/Z:Y/Z:1) if Z is not 0
*   - (0:1:0) if Z is 0
*
* (Note that in both cases the output point will be the equivalent to the input point)
*/
template normalizeProjective() {
    input ProjectivePoint() in;

    output ProjectivePoint() out;

    component ifThenElse = ifThenElseProjective();

    component isZZero = IsZero();
    isZZero.in <== in.Z;
    ifThenElse.cond <== isZZero.out;

    component getInfty = inftyProjective();
    ProjectivePoint() infty <== getInfty.out;
    ifThenElse.ifV <== infty;

    component divX = divisionSafe();
    component divY = divisionSafe();
    divX.numerator <== in.X;
    divX.denominator <== in.Z;
    divY.numerator <== in.Y;
    divY.denominator <== in.Z;
    ProjectivePoint() normalized;
    normalized.X <== divX.out;
    normalized.Y <== divY.out;
    normalized.Z <== 1;
    ifThenElse.elseV <== normalized;

    out <== ifThenElse.out;
}

// ========================================================================================================================
// BRANCHING:

template selectEnabledProjective(n) {
    input ProjectivePoint() in[n];
    input signal s[n];

    output ProjectivePoint() out;

    component selectEnabled = selectEnabledMulti(n, 3);
    component serializers[n];
    component deserializer = deserializeProjective();
    selectEnabled.s <== s;
    for(var i = 0; i < n; i++) {
        serializers[i] = serializeProjective();
        serializers[i].in <== in[i];
        selectEnabled.in[i] <== serializers[i].out;
    }
    deserializer.in <== selectEnabled.out;
    out <== deserializer.out;
}

template ifThenElseProjective() {
    input ProjectivePoint() ifV;
    input ProjectivePoint() elseV;
    input signal cond;

    output ProjectivePoint() out;

    component serializerIfV = serializeProjective();
    component serializeElseV = serializeProjective();
    component deserializer = deserializeProjective();
    component ifThenElse = ifThenElseMulti(3);

    serializerIfV.in <== ifV;
    serializeElseV.in <== elseV;
    ifThenElse.ifV <== serializerIfV.out;
    ifThenElse.elseV <== serializeElseV.out;
    ifThenElse.cond <== cond;
    deserializer.in <== ifThenElse.out;
    out <== deserializer.out;
}

template switchCaseProjective(n) {
    input ProjectivePoint() in[n];
    input signal cond[n-1];

    output ProjectivePoint() out;

    component switchCase = switchCaseMulti(n, 3);
    component serializers[n];
    component deserializer = deserializeProjective();
    switchCase.cond <== cond;
    for(var i = 0; i < n; i++) {
        serializers[i] = serializeProjective();
        serializers[i].in <== in[i];
        switchCase.in[i] <== serializers[i].out;
    }
    deserializer.in <== switchCase.out;
    out <== deserializer.out;
}
