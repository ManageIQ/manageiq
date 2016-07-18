ManageIQ.angular.app.directive('daysCheck', function() {
  return {
    require: 'ngModel',
    link: function (scope, _elem, attrs, ctrl) {
      scope.$watch(attrs.ngModel, function() {
        if (angular.isDefined(ctrl.viewValue)) {
          setSomeDaysCheckedValidity(ctrl, attrs);
        }
      });
      ctrl.$parsers.push(function(value) {
        setSomeDaysCheckedValidity(ctrl, attrs);
        return value;
      });

      var setSomeDaysCheckedValidity = function(ctrl, attrs) {
        if (allDaysUnchecked(attrs.daysCheck)) {
          scope.timeProfileModel.some_days_checked = false;
        } else {
          scope.timeProfileModel.some_days_checked = true;
        }
      };

      var allDaysUnchecked = function(i) {
        var dayValues = _.times(7, _.constant(false));
        dayValues[i] = true;
        return angular.equals(scope.timeProfileModel.dayValues, dayValues);
      };
    }
  }
});
