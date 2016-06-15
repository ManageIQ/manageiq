ManageIQ.angular.app.directive('validationStatus', ['$rootScope', function($rootScope) {
  return {
    require: 'ngModel',
    link: function (scope, elem, attrs, ctrl) {
      ctrl.$validators.validationRequired = function (modelValue, viewValue) {
        if (angular.isDefined(viewValue) && viewValue === true) {
          scope.postValidationModelRegistry(attrs.prefix);
          return true;
        } else {
          $rootScope.$broadcast('setErrorOnTab', {tab: attrs.prefix});
          return false;
        }
      };
    }
  }
}]);
