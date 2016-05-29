ManageIQ.angular.app.directive('detectSpaces', function() {
  return {
    require: 'ngModel',
    link: function (_scope, _elem, _attrs, ctrl) {
      ctrl.$validators.detectedSpaces = function (_modelValue, viewValue) {
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
