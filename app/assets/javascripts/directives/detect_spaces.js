ManageIQ.angular.app.directive('detectSpaces', function() {
  return {
    require: 'ngModel',
    link: function (scope, elem, attrs, ctrl) {
      ctrl.$validators.detectedSpaces = function (modelValue, viewValue) {
        if (angular.isDefined(viewValue) && !detectedSpaces(viewValue)) {
          return true;
        }
        return false;
      };

      var detectedSpaces = function(s) {
        return /\s/g.test(s);
      }
    }
  }
});
