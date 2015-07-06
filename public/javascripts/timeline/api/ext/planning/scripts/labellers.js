/*==================================================
 *  Planning Labeller
 *==================================================
 */

Timeline.PlanningLabeller = function(locale) {
    this._locale = locale;
};

Timeline.PlanningLabeller.labels = [];

Timeline.PlanningLabeller.prototype.labelInterval = function(date, intervalUnit) {
    var n = Timeline.PlanningUnit.toNumber(date);
    
    var prefix = "";
    var divider = 1;
    var divider2 = 7;
    var labels = Timeline.PlanningLabeller.labels[this._locale];
    
    switch (intervalUnit) {
    case Timeline.PlanningUnit.DAY:     prefix = labels.dayPrefix;      break;
    case Timeline.PlanningUnit.WEEK:    prefix = labels.weekPrefix;     divider = 7;        divider2 = divider * 4; break;
    case Timeline.PlanningUnit.MONTH:   prefix = labels.monthPrefix;    divider = 28;       divider2 = divider * 3; break;
    case Timeline.PlanningUnit.QUARTER: prefix = labels.quarterPrefix;  divider = 28 * 3;   divider2 = divider * 4; break;
    case Timeline.PlanningUnit.YEAR:    prefix = labels.yearPrefix;     divider = 28 * 12;  divider2 = divider * 5; break;
    }
    return { text: prefix + Math.floor(n / divider), emphasized: (n % divider2) == 0 };
};

Timeline.PlanningLabeller.prototype.labelPrecise = function(date) {
    return Timeline.PlanningLabeller.labels[this._locale].dayPrefix + 
        Timeline.PlanningUnit.toNumber(date);
};
