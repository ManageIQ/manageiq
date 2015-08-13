ManageIQ.angularApplication.directive('checkpath', ['miqService', function (miqService){
  return {
    require: 'ngModel',
       link: function (scope, elem, attrs, ctrl) {
         scope.$watch("repoModel.repo_path", function() {
           if(ctrl.$modelValue != undefined && scope.afterGet) {
             setValidity(scope, ctrl, ctrl.$modelValue, false);
           }
         });
         ctrl.$parsers.push(function(value) {
           setValidity(scope, ctrl, ctrl.$viewValue, true);
           return value;
          });

      validPath = function(scope, path, bClearMsg) {
        modified_path = path.replace(/\\/g, "/");
        if(new RegExp("^//[^/].*/.+$").test(modified_path)) {
          if(bClearMsg) $('#flash_msg_div').text("");
          scope.path_type = "NAS";
          return true;
        }
        else if(/^\[[^\]].+\].*$/.test(modified_path)) {
          if(bClearMsg) $('#flash_msg_div').text("");
          scope.path_type = "VMFS";
          return true;
        }
        else {
          if(scope.formId == "new") {
            miqService.miqFlash("warn", "Need a valid UNC path");
          } else {
            miqService.miqFlash("error", "Incorrect UNC path");
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
}]);
