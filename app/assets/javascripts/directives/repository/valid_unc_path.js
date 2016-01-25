ManageIQ.angularApplication.directive('checkPath', function() {
  return {
    require: 'ngModel',
       link: function (scope, elem, attr, ctrl) {
         scope.$watch(attr.ngModel, function() {
           if(ctrl.$modelValue != undefined && scope.afterGet) {
             setValidity(scope, ctrl.$modelValue);
           }
         });

         ctrl.$validators.checkPath = function (modelValue, viewValue) {
           if (angular.isDefined(viewValue) && checkPath(scope, viewValue)) {
             return true
           }
           return false;
         };

         var checkPath = function(scope, path) {
           modified_path = path.replace(/\\/g, "/");
           if(new RegExp("^//[^/].*/.+$").test(modified_path)) {
             scope.path_type = "NAS";
             return true;
           }
           else if(/^\[[^\]].+\].*$/.test(modified_path)) {
             scope.path_type = "VMFS";
             return true;
           }
           else {
             return false;
           }
         };

         var setValidity = function(scope, value) {
           if(checkPath(scope, value)) {
             ctrl.$setValidity("checkPath", true);
           } else {
             ctrl.$setValidity("checkPath", false);
           }
         };
      }
    }
});
