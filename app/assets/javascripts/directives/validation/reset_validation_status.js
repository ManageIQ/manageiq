ManageIQ.angular.app.directive('resetValidationStatus', ['$rootScope', function($rootScope) {
  return {
    require: 'ngModel',
    link: function (scope, elem, attrs, ctrl) {
      scope.$watch(attrs.ngModel, function() {
        adjustValidationStatus(ctrl.$modelValue, scope, ctrl, attrs, $rootScope);
      });

      ctrl.$parsers.push(function(value) {
        adjustValidationStatus(value, scope, ctrl, attrs, $rootScope);
        return value;
      });
    }
  }
}]);

var adjustValidationStatus = function(value, scope, ctrl, attrs, rootScope) {
  if(scope.checkAuthentication === true &&
     angular.isDefined(scope.postValidationModel) &&
     angular.isDefined(scope.postValidationModel[attrs.prefix])) {
    var modelPostValidationObject = angular.copy(scope.postValidationModel[attrs.prefix]);
    delete modelPostValidationObject[ctrl.$name];

    var modelObject = angular.copy(scope[scope.model]);
    if(angular.isDefined(modelObject[ctrl.$name])) {
      delete modelObject[ctrl.$name];
    }

    if (value == scope.postValidationModel[attrs.prefix][ctrl.$name] && _.isMatch(modelObject, modelPostValidationObject)) {
      scope[scope.model][attrs.resetValidationStatus] = true;
      rootScope.$broadcast('clearErrorOnTab', {tab: attrs.prefix});
    } else {
      scope[scope.model][attrs.resetValidationStatus] = false;
      rootScope.$broadcast('setErrorOnTab', {tab: attrs.prefix});
    }
  }
};
