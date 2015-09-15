ManageIQ.angularApplication.directive('verifypasswd', function() {
  return {
    require: 'ngModel',
    link: function (scope, elem, attr, ctrl) {

      var log_password = attr.prefix + "_password";
      var log_verify = attr.prefix + "_verify";
      var logVerifyCtrl = attr.prefix + "_VerifyCtrl";


      scope.$watch(attr.ngModel, function() {
        if((ctrl.$modelValue != undefined && scope.afterGet) || scope.formId == "new") {
          if(ctrl.$name == log_verify) {
            scope[logVerifyCtrl] = ctrl;

            setValidity(scope, ctrl, ctrl.$viewValue, scope[scope.model][log_password]);
          }else if(ctrl.$name == log_password && scope[logVerifyCtrl] != undefined) {
            setValidity(scope, scope[logVerifyCtrl], ctrl.$viewValue, scope[scope.model][log_verify]);
          }
        }
      });

      ctrl.$parsers.push(function(value) {
        if(ctrl.$name == log_verify) {
          setValidity(scope, ctrl, ctrl.$viewValue, scope[scope.model][log_password]);
        }else if(ctrl.$name == log_password && scope[logVerifyCtrl] != undefined) {
          setValidity(scope, scope[logVerifyCtrl], ctrl.$viewValue, scope[scope.model][log_verify]);
        }
        return value;
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
