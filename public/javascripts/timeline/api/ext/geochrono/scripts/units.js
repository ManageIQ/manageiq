/*==================================================
 *  Geochrono Unit
 *==================================================
 */

Timeline.GeochronoUnit = new Object();

Timeline.GeochronoUnit.MA     = 0;
Timeline.GeochronoUnit.AGE    = 1;
Timeline.GeochronoUnit.EPOCH  = 2;
Timeline.GeochronoUnit.PERIOD = 3;
Timeline.GeochronoUnit.ERA    = 4;
Timeline.GeochronoUnit.EON    = 5;

Timeline.GeochronoUnit.getParser = function(format) {
    return Timeline.GeochronoUnit.parseFromObject;
};

Timeline.GeochronoUnit.createLabeller = function(locale, timeZone) {
    return new Timeline.GeochronoLabeller(locale);
};

Timeline.GeochronoUnit.wrapMA = function (n) {
    return new Timeline.GeochronoUnit._MA(n);
};

Timeline.GeochronoUnit.makeDefaultValue = function () {
    return Timeline.GeochronoUnit.wrapMA(0);
};

Timeline.GeochronoUnit.cloneValue = function (v) {
    return new Timeline.GeochronoUnit._MA(v._n);
};

Timeline.GeochronoUnit.parseFromObject = function(o) {
    if (o instanceof Timeline.GeochronoUnit._MA) {
        return o;
    } else if (typeof o == "number") {
        return Timeline.GeochronoUnit.wrapMA(o);
    } else if (typeof o == "string" && o.length > 0) {
        return Timeline.GeochronoUnit.wrapMA(Number(o));
    } else {
        return null;
    }
};

Timeline.GeochronoUnit.toNumber = function(v) {
    return v._n;
};

Timeline.GeochronoUnit.fromNumber = function(n) {
    return new Timeline.GeochronoUnit._MA(n);
};

Timeline.GeochronoUnit.compare = function(v1, v2) {
    var n1, n2;
    if (typeof v1 == "object") {
        n1 = v1._n;
    } else {
        n1 = Number(v1);
    }
    if (typeof v2 == "object") {
        n2 = v2._n;
    } else {
        n2 = Number(v2);
    }
    
    return n2 - n1;
};

Timeline.GeochronoUnit.earlier = function(v1, v2) {
    return Timeline.GeochronoUnit.compare(v1, v2) < 0 ? v1 : v2;
};

Timeline.GeochronoUnit.later = function(v1, v2) {
    return Timeline.GeochronoUnit.compare(v1, v2) > 0 ? v1 : v2;
};

Timeline.GeochronoUnit.change = function(v, n) {
    return new Timeline.GeochronoUnit._MA(v._n - n);
};

Timeline.GeochronoUnit._MA = function(n) {
    this._n = n;
};

