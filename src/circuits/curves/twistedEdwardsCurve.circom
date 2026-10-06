pragma circom 2.2.1;
include "../utilities/arithmetic.circom";
include "../utilities/branching.circom";
include "../../../libs/node_modules/circomlib/circuits/bitify.circom";

// ========================================================================================================================
// Twisted Edwards points
bus TwistedEdwardsPoint() {
    signal x;
    signal y;
}

template ifThenElseTwistedEdwards() {
    input TwistedEdwardsPoint ifV;
    input TwistedEdwardsPoint elseV;
    input signal cond;

    output TwistedEdwardsPoint out;

    component xIfThenElse = ifThenElse();
    component yIfThenElse = ifThenElse();

    xIfThenElse.ifV <== ifV.x;
    xIfThenElse.elseV <== elseV.x;
    xIfThenElse.cond <== cond;
    yIfThenElse.ifV <== ifV.y;
    yIfThenElse.elseV <== elseV.y;
    yIfThenElse.cond <== cond;

    out.x <== xIfThenElse.out;
    out.y <== yIfThenElse.out;
}

template switchCaseTwistedEdwards(n) {
    input TwistedEdwardsPoint in[n];
    input signal cond[n];

    output TwistedEdwardsPoint out;

    component xSwitchCase = switchCase(n);
    component ySwitchCase = switchCase(n);

    for(var i = 0; i < n-1; i++) {
        xSwitchCase.in[i] <== in[i].x;
        ySwitchCase.in[i] <== in[i].y;
        xSwitchCase.cond[i] <== cond[i];
        ySwitchCase.cond[i] <== cond[i];
    }
    xSwitchCase.in[n-1] <== in[n-1].x;
    ySwitchCase.in[n-1] <== in[n-1].y;
    
    out.x <== xSwitchCase.out;
    out.y <== ySwitchCase.out;
}

template inftyTwistedEdwards() {
    output TwistedEdwardsPoint out;
    out.x <== 0;
    out.y <== 1;
}

// ========================================================================================================================
// Elliptic curve operations

/**
* Computes p1+p2 according to the definition of the group law in "Twisted Edwards Curves" by Bernstein et al./
*
* -> 7 constraints
*/
template twistedEdwardsGroupLaw(a, d) {
    input TwistedEdwardsPoint p1;
    input TwistedEdwardsPoint p2;

    output TwistedEdwardsPoint out;

    component xDivision = division();
    component yDivision = division();

    signal x1y2 <== p1.x * p2.y;
    signal x2y1 <== p2.x * p1.y;
    signal x1x2 <== p1.x * p2.x;
    signal y1y2 <== p1.y * p2.y;
    signal dx1x2y1y2 <== d * x1x2 * y1y2;
    xDivision.numerator <== x1y2 + x2y1;
    xDivision.denominator <== 1 + dx1x2y1y2;
    yDivision.numerator <== y1y2 - a * x1x2;
    yDivision.denominator <== 1 - dx1x2y1y2;

    out.x <== xDivision.out;
    out.y <== yDivision.out;
}

/**
* Computes the m * P, where m=[m_0,m_1,\dots, m_{n-1}] is given as a bitstring in LSB order.
* Furthermore, powersOfP provides [P, 2*P, 4*P, 8*P,\dots, 2^{l-1}*P].
*
* -> 9n-4 Constraints (e.g., 2291 Constraints for n=255)
*/
template twistedEdwardsScalarMul(n, a, d) {
    input TwistedEdwardsPoint powersOfP[n];
    input signal m;

    output TwistedEdwardsPoint out;

    component toBits = Num2Bits(n);
    toBits.in <== m;
    signal mBits[n] <== toBits.out;

    component infty = inftyTwistedEdwards();
    TwistedEdwardsPoint intermediateResults[n+1];
    intermediateResults[0] <== infty.out;
    component adders[n];
    component ifThenElse[n];

    for(var i = 0; i < n; i++) {
        adders[i] = twistedEdwardsGroupLaw(a, d);
        ifThenElse[i] = ifThenElseTwistedEdwards();

        adders[i].p1 <== intermediateResults[i];
        adders[i].p2 <== powersOfP[i];
        ifThenElse[i].ifV <== adders[i].out;
        ifThenElse[i].elseV <== intermediateResults[i];
        ifThenElse[i].cond <== mBits[i];

        intermediateResults[i+1] <== ifThenElse[i].out;
    }

    out <== intermediateResults[n];
}

/**
* Computes the m * P, where m=[m_0,m_1,\dots, m_{n-1}] is given as a representation to base "base" in LSB order. (For brevity, we use b to denote base here)
* Here, m_i = [m_{i,0}, \dots, m_{i,b-1}] is a unary coding of m_i with m_{i,j} = 1 exactly if m_i = j
* Furthermore, powersOfP provides 
*   [   
*       [e, 1*P, 2*1*P,\dots, (b-1)*1*P],
*       [e, b*P, 2*b*P,\dots, (b-1)*b*P],
*       [e, (b^2)*P, 2*(b^2)*P,\dots, (b-1)*(b^2)*P],
*       \dots,
*       [e, (b^{l-1})*P, 2*(b^{l-1})*P,\dots, (b-1)*(b^{n-1})*P]
*   ]
*
* -> Minumum of constraints for base=5
*/
template twistedEdwardsScalarMulArbitraryBase(base, n, a, d) {
    input TwistedEdwardsPoint powersOfP[n][base];
    input signal m[n][base];

    output TwistedEdwardsPoint out;

    component infty = inftyTwistedEdwards();
    TwistedEdwardsPoint intermediateResults[n+1];
    intermediateResults[0] <== infty.out;
    component adders[n];
    component switchCase[n];

    for(var i = 0; i < n; i++) {
        switchCase[i] = switchCaseTwistedEdwards(base);
        adders[i] = twistedEdwardsGroupLaw(a, d);

        switchCase[i].in <== powersOfP[i];
        switchCase[i].cond <== m[i];

        adders[i].p1 <== intermediateResults[i];
        adders[i].p2 <== switchCase[i].out;
        intermediateResults[i+1] <== adders[i].out;
    }

    out <== intermediateResults[n];
}



// ========================================================================================================================
// TE points as parameters

template twistedEdwardsScalarMulArbitraryBaseFixedPowers(base, n, a, d, powersOfP) {
    input signal m[n][base];

    output TwistedEdwardsPoint out;

    TwistedEdwardsPoint powers[n][base];

    component infty = inftyTwistedEdwards();
    TwistedEdwardsPoint intermediateResults[n+1];
    intermediateResults[0] <== infty.out;
    component adders[n];
    component switchCase[n];

    for(var i = 0; i < n; i++) {
        switchCase[i] = switchCaseTwistedEdwards(base);
        adders[i] = twistedEdwardsGroupLaw(a, d);

        for(var j = 0; j < base; j++) {
            powers[i][j].x <== powersOfP[i][j][0];
            powers[i][j].y <== powersOfP[i][j][1];
        }
        switchCase[i].in <== powers[i];
        switchCase[i].cond <== m[i];

        adders[i].p1 <== intermediateResults[i];
        adders[i].p2 <== switchCase[i].out;
        intermediateResults[i+1] <== adders[i].out;
    }

    out <== intermediateResults[n];
}


template twistedEdwardsScalarMulFixedPowers(n, a, d, powers) {
    input signal mBits[n];

    output TwistedEdwardsPoint out;

    TwistedEdwardsPoint powersOfP[n];
    for(var i = 0; i < n; i++) {
        powersOfP[i].x <== powers[i][0];
        powersOfP[i].y <== powers[i][1];
    }

    component infty = inftyTwistedEdwards();
    TwistedEdwardsPoint intermediateResults[n+1];
    intermediateResults[0] <== infty.out;
    component adders[n];
    component ifThenElse[n];

    for(var i = 0; i < n; i++) {
        adders[i] = twistedEdwardsGroupLaw(a, d);
        ifThenElse[i] = ifThenElseTwistedEdwards();

        adders[i].p1 <== intermediateResults[i];
        adders[i].p2 <== powersOfP[i];
        ifThenElse[i].ifV <== adders[i].out;
        ifThenElse[i].elseV <== intermediateResults[i];
        ifThenElse[i].cond <== mBits[i];

        intermediateResults[i+1] <== ifThenElse[i].out;
    }

    out <== intermediateResults[n];
}



/*
component main = twistedEdwardsScalarMulArbitraryBaseFixedPowers(5, 3, 126934, 126930, [
    [[0,1],[9448001257521873467800434588747872420327391111382672762676805338150480454144,15439816180694400015484557974569487149071268870516806316179292452968275247338],[12394166259745173361886191545398136527545178199368011277918107292258910499951,8445056090707285639985458056772320285481876358509027301821308865125593291842],[7303749705636030565949847665715340692531905251315836439453453122833092299440,18747230969204435907733623654254276626835211709258310697124621687240640009057],[18162009345139572058165773297386593882687111963613380056710478606935187619274,19108578907242599729892298379921182781026857220875619099109439041687855184654]],
    [[0,1],[14809460284809179326721746896188963306796758645150140495076789361517030897094,14070195355797621284790385795318629927561083569948926734073876255737872936847],[14933106216459490010428960117461862203708337189910571842271046011164584772449,13149919871757455436007945997385695426213929471619740063214902767138530793100],[16285630960249394096656215032295821350257525256960092726135608513036394847976,7284594577775403515312755075517485491332570630598578777332919028799366266723],[15770680819451133397840754610756432871933021348370919331042232031495578436956, 9193041451483139955652568037541290539897425789413024658510999998247754683032]],
    [[0,1],[13268716409270892488670313359316147177642341442579202577908780131905203896309,13264919265089865241501253770696865048867391211562919047099439401559291252468],[10370113550451045620619191392705286934409326726111065539442334620924783076260,3274581614465035161423791295954770572388188549844800902399593628865143705016],[2816326003049186282598097785201909511543204117049180143690930741211931973753,11709212668658214402826552572567682900254707148258957091120115101657444704232],[14998106480513103612903875693126580080599262205778165370021686190182420200120,14445761321838192382629902896001620410893560788579311565310308125184849730251]]
    ]
);
*/

/*
component main = twistedEdwardsScalarMulArbitraryBaseFixedPowers(2, 3, 126934, 126930, [
    [[0,1],[9448001257521873467800434588747872420327391111382672762676805338150480454144,15439816180694400015484557974569487149071268870516806316179292452968275247338]],
    [[0,1],[12394166259745173361886191545398136527545178199368011277918107292258910499951,8445056090707285639985458056772320285481876358509027301821308865125593291842]],
    [[0,1],[18162009345139572058165773297386593882687111963613380056710478606935187619274,19108578907242599729892298379921182781026857220875619099109439041687855184654]]
    ]
);
*/

// component main = twistedEdwardsScalarMulFixedPoint(255, 126934, 126930, [9448001257521873467800434588747872420327391111382672762676805338150480454144,15439816180694400015484557974569487149071268870516806316179292452968275247338]);
// component main = twistedEdwardsScalarMulFixedPoint(255, 126934, 126930, [9448001257521873467800434588747872420327391111382672762676805338150480454144,15439816180694400015484557974569487149071268870516806316179292452968275247338]);

// component main = twistedEdwardsScalarMulFixedPowers(2, 126934, 126930, [[9448001257521873467800434588747872420327391111382672762676805338150480454144,15439816180694400015484557974569487149071268870516806316179292452968275247338], [12394166259745173361886191545398136527545178199368011277918107292258910499951, 8445056090707285639985458056772320285481876358509027301821308865125593291842]]); //, [18162009345139572058165773297386593882687111963613380056710478606935187619274, 19108578907242599729892298379921182781026857220875619099109439041687855184654]]);
// component main = twistedEdwardsScalarMulArbitraryBase(5, 2, 126934, 126930);
// component main = twistedEdwardsScalarMul(255, 126934, 126930);
