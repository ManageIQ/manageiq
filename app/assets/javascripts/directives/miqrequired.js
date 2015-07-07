miqAngularApplication.directive('miqrequired', function() {
  return {
    require: 'ngModel',
      link: function (scope, elem, attrs, ctrl) {
        scope.$watch(attrs.ngModel, function() {
          if((ctrl.$modelValue != undefined && scope.afterGet) || scope.formId == "new") {
            setValidity(scope, ctrl, ctrl.$modelValue);
          }
        });
        ctrl.$parsers.unshift(function(val) {
          setValidity(scope, ctrl, ctrl.$viewValue);
          return val;
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
