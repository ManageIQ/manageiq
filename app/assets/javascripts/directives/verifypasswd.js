ManageIQ.angularApplication.directive('verifypasswd', function() {
  return {
    require: 'ngModel',
    link: function (scope, elem, attr, ctrl) {

      var modelName = attr.verifypasswd;

      scope.$watch(attr.ngModel, function() {
        if (ctrl.$name.endsWith("_verify")){
          verify_field = ctrl.$name
          password_field = verify_field.split("_")[0] + "_password"
        }

        if (ctrl.$name.endsWith("_password")){
          password_field = ctrl.$name
          verify_field = password_field.split("_")[0] + "_verify"
        }
        if((ctrl.$modelValue != undefined && scope.afterGet) || scope.formId == "new") {
          if(ctrl.$name == verify_field) {
            scope.logVerifyCtrl = ctrl;
            setValidity(scope, ctrl, ctrl.$viewValue, scope[modelName][password_field]);
          }else if(ctrl.$name == password_field && scope.logVerifyCtrl != undefined) {
            setValidity(scope, scope.logVerifyCtrl, ctrl.$viewValue, scope[modelName][verify_field]);
          }
        }
      });


//      ctrl.$parsers.push(function(value) {
//        if(ctrl.$name == "log_verify") {
//          setValidity(scope, ctrl, ctrl.$viewValue, scope[modelName].log_password);
//        }else if(ctrl.$name == "log_password" && scope.logVerifyCtrl != undefined) {
//          setValidity(scope, scope.logVerifyCtrl, ctrl.$viewValue, scope[modelName].log_verify);

      ctrl.$parsers.unshift(function() {
        if (ctrl.$name.endsWith("_verify")){
          verify_field = ctrl.$name
          password_field = verify_field.split("_")[0] + "_password"
        }

        if (ctrl.$name.endsWith("_password")){
          password_field = ctrl.$name
          verify_field = password_field.split("_")[0] + "_verify"
        }

        if(ctrl.$name == verify_field) {
          setValidity(scope, ctrl, ctrl.$viewValue, scope[modelName][password_field]);
        }else if(ctrl.$name == password_field && scope.logVerifyCtrl != undefined) {
          setValidity(scope, scope.logVerifyCtrl, ctrl.$viewValue, scope[modelName][verify_field]);
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
