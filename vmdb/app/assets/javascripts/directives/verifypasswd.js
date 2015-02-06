cfmeAngularApplication.directive('verifypasswd', function() {
  return {
    require: 'ngModel',
    link: function (scope, elem, attr, ctrl) {

      var modelName = attr.verifypasswd;

      scope.$watch(attr.ngModel, function() {
        if((ctrl.$modelValue != undefined && scope.afterGet) || scope.formId == "new") {
          if(ctrl.$name == "log_verify") {
            scope.logVerifyCtrl = ctrl;
            setValidity(scope, ctrl, ctrl.$viewValue, scope[modelName].log_password);
          }else if(ctrl.$name == "log_password" && scope.logVerifyCtrl != undefined) {
            setValidity(scope, scope.logVerifyCtrl, ctrl.$viewValue, scope[modelName].log_verify);
          }
        }
      });

      ctrl.$parsers.unshift(function() {
        if(ctrl.$name == "log_verify") {
          setValidity(scope, ctrl, ctrl.$viewValue, scope[modelName].log_password);
        }else if(ctrl.$name == "log_password" && scope.logVerifyCtrl != undefined) {
          setValidity(scope, scope.logVerifyCtrl, ctrl.$viewValue, scope[modelName].log_verify);
        }
      });

      var setValidity = function(scope, logVerifyCtrl, valueNew, valueOrig) {
        if (valueNew == valueOrig) {
          logVerifyCtrl.$setValidity("verifypasswd", true);
        } else {
          if(logVerifyCtrl.$dirty || valueOrig != "")
            logVerifyCtrl.$setValidity("verifypasswd", false);
        }
      };
    }
  }
});