miqAngularApplication.directive('miqrequired', function() {
  return {
    require: 'ngModel',
      link: function (scope, elem, attrs, ctrl) {
        scope.$watch(attrs.ngModel, function() {
          if((ctrl.$modelValue != undefined)) {
            setValidity(scope, ctrl, ctrl.$modelValue);
          }
        });
        ctrl.$parsers.push(function(value) {
          setValidity(scope, ctrl, ctrl.$viewValue);
          return value;
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