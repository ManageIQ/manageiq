ManageIQ.angular.app.directive('resetValidationStatus', function() {
  return {
    require: 'ngModel',
    link: function (scope, elem, attrs, ctrl) {
      scope.$watch(attrs.ngModel, function() {
        adjustValidationStatus(ctrl.$modelValue, scope, ctrl, attrs);
      });

      ctrl.$parsers.push(function(value) {
        adjustValidationStatus(value, scope, ctrl, attrs);
        return value;
      });
    }
  }
});

var adjustValidationStatus = function(value, scope, ctrl, attrs) {

  if(scope.checkAuthentication === true && angular.isDefined(scope.postValidationModel)) {
    var modelPostValidationObject = angular.copy(scope.postValidationModel);
    delete modelPostValidationObject[ctrl.$name];

    var modelObject = angular.copy(scope[scope.model]);
    if(angular.isDefined(modelObject[ctrl.$name])) {
      delete modelObject[ctrl.$name];
    }

    if (value == scope.postValidationModel[ctrl.$name] && _.isMatch(modelObject, modelPostValidationObject)) {
      scope[scope.model][attrs.resetValidationStatus] = true;
    } else {
      scope[scope.model][attrs.resetValidationStatus] = false;
    }
  }
};
