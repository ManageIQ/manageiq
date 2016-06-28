ManageIQ.angular.app.directive('requiredDependsOn', function() {
  return {
    require: 'ngModel',
    link: function (scope, _elem, attrs, ctrl) {
      scope.$watch(attrs.ngModel, function() {
        if ((ctrl.$modelValue != undefined)) {
          setValidityForModelValue(scope, ctrl, ctrl.$modelValue, attrs.requiredIfExists);
        }
      });
      ctrl.$parsers.push(function(value) {
        setValidityForModelValue(scope, ctrl, value, attrs.requiredIfExists);
        return value;
      });
      scope.$watch(attrs.requiredDependsOn, function(dependsOnValue) {
        if ((ctrl.$modelValue != undefined)) {
          setValidity(scope, ctrl, ctrl.$modelValue, dependsOnValue);
        }
      });

      var setValidity = function(_scope, ctrl, value, dependsOnValue) {
        if (value == "" && dependsOnValue != "") {
          ctrl.$setValidity("requiredDependsOn", false);
        } else {
          ctrl.$setValidity("requiredDependsOn", true);
        }
      };

      var setValidityForModelValue = function(scope, ctrl, value, valueIfExists) {
        if (value == "" && scope[scope.model][valueIfExists] != "") {
          ctrl.$setValidity("requiredDependsOn", false);
        } else {
          ctrl.$setValidity("requiredDependsOn", true);
        }
      };
    }
  }
});
