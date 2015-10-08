ManageIQ.angularApplication.directive('requiredIfExisted', function() {
  return {
    require: 'ngModel',
    link: function (scope, elem, attrs, ctrl) {
      scope.$watch(attrs.ngModel, function() {
        if((ctrl.$modelValue != undefined)) {
          setValidity(scope, ctrl, ctrl.$modelValue);
        }
      });
      scope.$watch(attrs.requiredDependsOn, function() {
        if((ctrl.$modelValue != undefined)) {
          setValidity(scope, ctrl, ctrl.$modelValue);
        }
      });
      ctrl.$parsers.push(function(value) {
        setValidity(scope, ctrl, ctrl.$viewValue);
        return value;
      });

      var setValidity = function(scope, ctrl, value) {
        if(value == "" && (scope.modelCopy[ctrl.$name] != "" || scope[scope.model][attrs.requiredIfExisted] != "")) {
          ctrl.$setValidity("requiredIfExisted", false);
        } else {
          ctrl.$setValidity("requiredIfExisted", true);
        }
      };
    }
  }
});
