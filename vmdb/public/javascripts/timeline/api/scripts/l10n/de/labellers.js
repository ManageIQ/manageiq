/*==================================================
 *  Localization of labellers.js
 *==================================================
 */

Timeline.GregorianDateLabeller.monthNames["de"] = [
    "Jan", "Feb", "Mrz", "Apr", "Mai", "Jun", "Jul", "Aug", "Sep", "Okt", "Nov", "Dez"
];

Timeline.GregorianDateLabeller.labelIntervalFunctions["de"] = function(date, intervalUnit) {
    var text;
    var emphasized = false;
    
    var date2 = Timeline.DateTime.removeTimeZoneOffset(date, this._timeZone);
    
    switch(intervalUnit) {
    case Timeline.DateTime.DAY:
    case Timeline.DateTime.WEEK:
        text = date2.getUTCDate() + ". " +
            Timeline.GregorianDateLabeller.getMonthName(date2.getUTCMonth(), this._locale);
        break;
    default:
        return this.defaultLabelInterval(date, intervalUnit);
    }
    
    return { text: text, emphasized: emphasized };
};