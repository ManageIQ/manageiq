ManageIQ.angular.app.directive('someDaysCheck', function() {
  return {
    require: 'ngModel',
    link: function (scope, _elem, attrs, ctrl) {
      ctrl.$validators.someDaysCheck = function (_modelValue, _viewValue) {
        return !allDaysUnchecked(scope);
      };

      var allDaysUnchecked = function(scope) {
        var dayValues = _.times(7, _.constant(false));
        return angular.equals(scope.timeProfileModel.dayValues, dayValues);
      }
    }
  }
});
