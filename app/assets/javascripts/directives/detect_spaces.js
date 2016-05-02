ManageIQ.angular.app.directive('detectSpaces', function() {
  return {
    require: 'ngModel',
    link: function (scope, elem, attrs, ctrl) {
      scope.$watch(attrs.ngModel, function() {
        if((ctrl.$modelValue != undefined)) {
          setValidityForSpaces(ctrl, ctrl.$modelValue);
        }
      });
      ctrl.$parsers.push(function(value) {
        setValidityForSpaces(ctrl, value);
        return value;
      });

      var setValidityForSpaces = function(ctrl, value) {
        if(hasWhiteSpace(value)) {
          ctrl.$setValidity("detectedSpaces", false);
        } else {
          ctrl.$setValidity("detectedSpaces", true);
        }
      };

      var hasWhiteSpace = function(s) {
        return /\s/g.test(s);
      }
    }
  }
});
