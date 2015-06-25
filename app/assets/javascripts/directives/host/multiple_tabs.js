ManageIQ.angularApplication.directive('checkpath', function (){
  return {
    require: 'ngModel',
       link: function (scope, elem, attrs, ctrl) {
       ctrl.$parsers.unshift(function() {
       if(validPath(scope,  ctrl.$viewValue)) {
         ctrl.$setValidity('checkpath', true);
        }
        else {
          ctrl.$setValidity('checkpath', false);
        }
      });

      validPath = function(scope, path) {
        modified_path = path.replace(/\\/g, "/");
        if(new RegExp("^//[^/].*/.+$").test(modified_path)) {
          $j('#flash_msg_div').text("");
          scope.path_type = "NAS";
          return true;
        }
        else if(/^\[[^\]].+\].*$/.test(modified_path)) {
          $j('#flash_msg_div').text("");
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
    }
  }
});
