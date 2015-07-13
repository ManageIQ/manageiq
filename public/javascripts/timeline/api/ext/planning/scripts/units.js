/*==================================================
 *  Planning Unit
 *==================================================
 */

Timeline.PlanningUnit = new Object();

Timeline.PlanningUnit.DAY     = 0;
Timeline.PlanningUnit.WEEK    = 1;
Timeline.PlanningUnit.MONTH   = 2;
Timeline.PlanningUnit.QUARTER = 3;
Timeline.PlanningUnit.YEAR    = 4;

Timeline.PlanningUnit.getParser = function(format) {
    return Timeline.PlanningUnit.parseFromObject;
};

Timeline.PlanningUnit.createLabeller = function(locale, timeZone) {
    return new Timeline.PlanningLabeller(locale);
};

Timeline.PlanningUnit.makeDefaultValue = function () {
    return 0;
};

Timeline.PlanningUnit.cloneValue = function (v) {
    return v;
};

Timeline.PlanningUnit.parseFromObject = function(o) {
    if (o == null) {
        return null;
    } else if (typeof o == "number") {
        return o;
    } else {
        try {
            return parseInt(o);
        } catch (e) {
            return null;
        }
    }
};

Timeline.PlanningUnit.toNumber = function(v) {
    return v
};

Timeline.PlanningUnit.fromNumber = function(n) {
    return n;
};

Timeline.PlanningUnit.compare = function(v1, v2) {
    return v1 - v2;
};

Timeline.PlanningUnit.earlier = function(v1, v2) {
    return Timeline.PlanningUnit.compare(v1, v2) < 0 ? v1 : v2;
};

Timeline.PlanningUnit.later = function(v1, v2) {
    return Timeline.PlanningUnit.compare(v1, v2) > 0 ? v1 : v2;
};

Timeline.PlanningUnit.change = function(v, n) {
    return v + n;
};
