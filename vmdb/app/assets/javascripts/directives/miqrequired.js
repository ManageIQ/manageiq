cfmeAngularApplication.directive('miqrequired', function() {
  return {
    require: 'ngModel',
      link: function (scope, elem, attrs, ctrl) {
        scope.$watch(attrs.ngModel, function() {
          if((ctrl.$modelValue != undefined && scope.afterGet) || scope.formId == "new") {
            setValidity(scope, ctrl, ctrl.$modelValue);
          }
        });
        ctrl.$parsers.unshift(function() {
          setValidity(scope, ctrl, ctrl.$viewValue);
        });

        var setValidity = function(scope, ctrl, value) {
          if(value != "") {
            ctrl.$setValidity("miqrequired", true);
          } else {
            ctrl.$setValidity("miqrequired", false);
          }
        };
      }
  }
});