pragma circom 2.2.1;

include "../utilities/branching.circom";
include "../../../libs/node_modules/circomlib/circuits/comparators.circom";

/**
* Represents an affine point (x,y). notInfty is 0 if the point is the point at infinity and 1 otherwise.
*/
bus AffinePoint() {
    signal x;
    signal y;
    signal notInfty;
}

// ========================================================================================================================
//(DE-)SERIALIZING:

template serializeAffine() {
    input AffinePoint() in;
    output signal out[3];
    out[0] <== in.x;
    out[1] <== in.y;
    out[2] <== in.notInfty;
}

template deserializeAffine() {
    input signal in[3];
    output AffinePoint out;
    out.x <== in[0];
    out.y <== in[1];
    out.notInfty <== in[2];
}

// ========================================================================================================================
// SPECIAL POINTS:
template inftyAffine() {
    output AffinePoint out;
    out.x <== 0;
    out.y <== 0;
    out.notInfty <== 0;
}

template zeroAffine() {
    output AffinePoint() out;

    out.x <== 0;
    out.y <== 0;
    out.notInfty <== 1;
}

/**
* Checks whether the given point (x,y) is (0,0).
*/
template isZeroAffine() {
    input AffinePoint() in;

    output signal out;

    component isxZero = IsZero();
    component isyZero = IsZero();
    isxZero.in <== in.x;
    isyZero.in <== in.y;
    out <== isxZero.out * isyZero.out;
}

// ========================================================================================================================
// BRANCHING:

template selectEnabledAffine(n) {
    input AffinePoint() in[n];
    input signal s[n];

    output AffinePoint() out;

    component selectEnabled = selectEnabledMulti(n, 3);
    component serializers[n];
    component deserializer = deserializeAffine();
    selectEnabled.s <== s;
    for(var i = 0; i < n; i++) {
        serializers[i] = serializeAffine();
        serializers[i].in <== in[i];
        selectEnabled.in[i] <== serializers[i].out;
    }
    deserializer.in <== selectEnabled.out;
    out <== deserializer.out;
}

template ifThenElseAffine() {
    input AffinePoint() ifV;
    input AffinePoint() elseV;
    input signal cond;

    output AffinePoint() out;

    component serializerIfV = serializeAffine();
    component serializeElseV = serializeAffine();
    component deserializer = deserializeAffine();
    component ifThenElse = ifThenElseMulti(3);

    serializerIfV.in <== ifV;
    serializeElseV.in <== elseV;
    ifThenElse.ifV <== serializerIfV.out;
    ifThenElse.elseV <== serializeElseV.out;
    ifThenElse.cond <== cond;
    deserializer.in <== ifThenElse.out;
    out <== deserializer.out;
}

template switchCaseAffine(n) {
    input AffinePoint() in[n];
    input signal cond[n-1];

    output AffinePoint() out;

    component switchCase = switchCaseMulti(n, 3);
    component serializers[n];
    component deserializer = deserializeAffine();
    switchCase.cond <== cond;
    for(var i = 0; i < n; i++) {
        serializers[i] = serializeAffine();
        serializers[i].in <== in[i];
        switchCase.in[i] <== serializers[i].out;
    }
    deserializer.in <== switchCase.out;
    out <== deserializer.out;
}

template switch_case_affine(n) {
    input AffinePoint() in[n];
    input signal cond[n];

    output AffinePoint() out;

    component xSwitchCase = switchCase(n);
    component ySwitchCase = switchCase(n);
    component notInftySwitchCase = switchCase(n);

    for(var i = 0; i < n-1; i++) {
        xSwitchCase.in[i] <== in[i].x;
        ySwitchCase.in[i] <== in[i].y;
        notInftySwitchCase.in[i] <== in[i].notInfty;
        xSwitchCase.cond[i] <== cond[i];
        ySwitchCase.cond[i] <== cond[i];
        notInftySwitchCase.cond[i] <== cond[i];
    }
    xSwitchCase.in[n-1] <== in[n-1].x;
    ySwitchCase.in[n-1] <== in[n-1].y;
    notInftySwitchCase.in[n-1] <== in[n-1].notInfty;
    
    out.x <== xSwitchCase.out;
    out.y <== ySwitchCase.out;
    out.notInfty <== notInftySwitchCase.out;
}