ManageIQ.angular.app.directive('someTimeCheck', function() {
  return {
    require: 'ngModel',
    link: function (scope, _elem, attrs, ctrl) {
      ctrl.$validators.someTimeCheck = function (_modelValue, _viewValue) {
        if (attrs.timeType === "day") {
          return !allDaysUnchecked(scope);
        } else if (attrs.timeType === "hour") {
          return !allHoursUnchecked(scope);
        }
      };

      var allDaysUnchecked = function(scope) {
        var dayValues = _.times(7, _.constant(false));
        return angular.equals(scope.timeProfileModel.dayValues, dayValues);
      };

      var allHoursUnchecked = function(scope) {
        var hourValues = _.times(24, _.constant(false));
        return angular.equals(scope.timeProfileModel.hourValues, hourValues);
      };
    }
  }
});
