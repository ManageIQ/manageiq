/*==================================================
 *  Default Unit
 *==================================================
 */

Timeline.NativeDateUnit = new Object();

Timeline.NativeDateUnit.createLabeller = function(locale, timeZone) {
    return new Timeline.GregorianDateLabeller(locale, timeZone);
};

Timeline.NativeDateUnit.makeDefaultValue = function() {
    return new Date();
};

Timeline.NativeDateUnit.cloneValue = function(v) {
    return new Date(v.getTime());
};

Timeline.NativeDateUnit.getParser = function(format) {
    if (typeof format == "string") {
        format = format.toLowerCase();
    }
    return (format == "iso8601" || format == "iso 8601") ?
        Timeline.DateTime.parseIso8601DateTime : 
        Timeline.DateTime.parseGregorianDateTime;
};

Timeline.NativeDateUnit.parseFromObject = function(o) {
    return Timeline.DateTime.parseGregorianDateTime(o);
};

Timeline.NativeDateUnit.toNumber = function(v) {
    return v.getTime();
};

Timeline.NativeDateUnit.fromNumber = function(n) {
    return new Date(n);
};

Timeline.NativeDateUnit.compare = function(v1, v2) {
    var n1, n2;
    if (typeof v1 == "object") {
        n1 = v1.getTime();
    } else {
        n1 = Number(v1);
    }
    if (typeof v2 == "object") {
        n2 = v2.getTime();
    } else {
        n2 = Number(v2);
    }
    
    return n1 - n2;
};

Timeline.NativeDateUnit.earlier = function(v1, v2) {
    return Timeline.NativeDateUnit.compare(v1, v2) < 0 ? v1 : v2;
};

Timeline.NativeDateUnit.later = function(v1, v2) {
    return Timeline.NativeDateUnit.compare(v1, v2) > 0 ? v1 : v2;
};

Timeline.NativeDateUnit.change = function(v, n) {
    return new Date(v.getTime() + n);
};

