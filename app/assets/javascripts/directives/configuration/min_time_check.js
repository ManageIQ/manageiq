ManageIQ.angular.app.directive('minTimeCheck', function() {
  return {
    require: 'ngModel',
    link: function (scope, _elem, attrs, ctrl) {
      scope.$watch(attrs.ngModel, function() {
        if (angular.isDefined(ctrl.viewValue)) {
          setSomePeriodCheckedValidity(ctrl, attrs);
        }
      });
      ctrl.$parsers.push(function(value) {
        setSomePeriodCheckedValidity(ctrl, attrs);
        return value;
      });

      var setSomePeriodCheckedValidity = function(ctrl, attrs) {
        if (attrs.timeType === "day") {
          if (allDaysUnchecked(attrs.minTimeCheck)) {
            scope.timeProfileModel.some_days_checked = false;
          } else {
            scope.timeProfileModel.some_days_checked = true;
            scope.timeProfileModel.all_days = false;
          }
        } else if (attrs.timeType === "hour") {
          if (allHoursUnchecked(attrs.minTimeCheck)) {
            scope.timeProfileModel.some_hours_checked = false;
          } else {
            scope.timeProfileModel.some_hours_checked = true;
            scope.timeProfileModel.all_hours = false;
          }
        }
      };

      var allDaysUnchecked = function(i) {
        var dayValues = _.times(7, _.constant(false));
        dayValues[i] = true;
        return angular.equals(scope.timeProfileModel.dayValues, dayValues);
      };

      var allHoursUnchecked = function(i) {
        return allFirstHalfAMHoursUnchecked(i) ||
               allSecondHalfAMHoursUnchecked(i) ||
               allFirstHalfPMHoursUnchecked(i) ||
               allSecondHalfPMHoursUnchecked(i)
      };

      var allFirstHalfAMHoursUnchecked = function(i) {
        var hourFirstHalfAMValues = _.times(6, _.constant(false));
        hourFirstHalfAMValues[i] = true;
        return angular.equals(scope.timeProfileModel.hourValuesAMFirstHalf, hourFirstHalfAMValues);
      };

      var allSecondHalfAMHoursUnchecked = function(i) {
        var hourSecondHalfAMValues = _.times(6, _.constant(false));
        hourSecondHalfAMValues[i] = true;
        return angular.equals(scope.timeProfileModel.hourValuesAMSecondHalf, hourSecondHalfAMValues);
      };

      var allFirstHalfPMHoursUnchecked = function(i) {
        var hourFirstHalfPMValues = _.times(6, _.constant(false));
        hourFirstHalfPMValues[i] = true;
        return angular.equals(scope.timeProfileModel.hourValuesPMFirstHalf, hourFirstHalfPMValues);
      };

      var allSecondHalfPMHoursUnchecked = function(i) {
        var hourSecondHalfPMValues = _.times(6, _.constant(false));
        hourSecondHalfPMValues[i] = true;
        return angular.equals(scope.timeProfileModel.hourValuesPMSecondHalf, hourSecondHalfPMValues);
      };
    }
  }
});
