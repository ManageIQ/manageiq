cfmeAngularApplication.directive('checkpath', function (){
  return {
    require: 'ngModel',
       link: function (scope, elem, attrs, ctrl) {
         scope.$watch("repoModel.repo_path", function() {
           if(ctrl.$modelValue != undefined && scope.afterGet) {
             setValidity(scope, ctrl, ctrl.$modelValue, false);
           }
         });
         ctrl.$parsers.unshift(function() {
           setValidity(scope, ctrl, ctrl.$viewValue, true);
          });

      validPath = function(scope, path, bClearMsg) {
        modified_path = path.replace(/\\/g, "/");
        if(new RegExp("^//[^/].*/.+$").test(modified_path)) {
          if(bClearMsg) $j('#flash_msg_div').text("");
          scope.path_type = "NAS";
          return true;
        }
        else if(/^\[[^\]].+\].*$/.test(modified_path)) {
          if(bClearMsg) $j('#flash_msg_div').text("");
          scope.path_type = "VMFS";
          return true;
        }
        else {
          if(scope.formId == "new") {
            scope.miqService.miqFlash("warn", "Need a valid UNC path");
          } else {
            scope.miqService.miqFlash("error", "Incorrect UNC path");
          }
          return false;
        }
      };

      var setValidity = function(scope, ctrl, value, bClearMsg) {
        if(validPath(scope, value, bClearMsg)) {
          ctrl.$setValidity("checkpath", true);
        } else {
          ctrl.$setValidity("checkpath", false);
        }
      };
    }
  }
});
