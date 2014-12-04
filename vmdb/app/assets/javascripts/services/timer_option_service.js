cfmeAngularApplication.service('timerOptionService', function() {
  var singularize = function(timeType) {
    return timeType.substring(0, timeType.length - 1);
  };

  var timeObject = function(timeType, value) {
    return {text: value + ' ' + timeType, value: value};
  };

  var timeDataBuilder = function(timeType, iterations) {
    var timeData = [];

    for(var value = 1; value <= iterations; value++) {
      if (value === 1) {
        timeData.push({text: singularize(timeType), value: value});
      } else {
        timeData.push(timeObject(timeType, value));
      }
    }

    return timeData;
  };

  var hourlyTimeOptions = [
    timeDataBuilder("Hours", 4),
    timeObject("Hours", 6),
    timeObject("Hours", 8),
    timeObject("Hours", 12)
  ].flatten();

  this.timerOptions = {
    "Once": [],
    "Hourly": hourlyTimeOptions,
    "Daily": timeDataBuilder("Days", 6),
    "Weekly": timeDataBuilder("Weeks", 4),
    "Monthly": timeDataBuilder("Months", 6)
  };

  this.getOptions = function(timerType) {
    return this.timerOptions[timerType];
  };
});
