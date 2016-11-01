ManageIQ.angular.app.directive('checkchange', ['miqService', function(miqService) {
  return {
    require: 'ngModel',
    link: function (scope, elem, attr, ctrl) {
      scope['formchange_' + ctrl.$name] = elem[0].name
      scope['elemType_' + ctrl.$name] = attr.type;

      if (angular.isDefined(scope.modelCopy)) {
        scope.$watch(attr.ngModel, function () {
          if (scope['elemType_' + ctrl.$name] == "date" || _.isDate(ctrl.$modelValue)) {
            viewModelDateComparison(scope, ctrl);
          } else {
            viewModelComparison(scope, ctrl);
          }
          if (scope.angularForm.$pristine)
            checkForOverallFormPristinity(scope, ctrl);
        });
      }

      ctrl.$parsers.push(function(value) {
        miqService.miqFlashClear();

        if (value == scope.modelCopy[ctrl.$name]) {
          scope.angularForm[scope['formchange_' + ctrl.$name]].$setPristine();
        }
        if (scope.angularForm[scope['formchange_' + ctrl.$name]].$pristine) {
          checkForOverallFormPristinity(scope, ctrl);
        }
        scope.angularForm[scope['formchange_' + ctrl.$name]].$setTouched();
        return value;
      });

      if(scope.angularForm.$pristine)
        scope.angularForm.$setPristine();
    }
  }
}]);

var viewModelComparison = function(scope, ctrl) {
  if ((Array.isArray(scope.modelCopy[ctrl.$name]) &&
       angular.equals(scope[scope.model][ctrl.$name], scope.modelCopy[ctrl.$name])) ||
       ctrl.$viewValue == scope.modelCopy[ctrl.$name]) {
    scope.angularForm[scope['formchange_' + ctrl.$name]].$setPristine();
    scope.angularForm[scope['formchange_' + ctrl.$name]].$setUntouched();
    scope.angularForm.$pristine = true;
  } else {
    scope.angularForm[scope['formchange_' + ctrl.$name]].$setDirty();
    scope.angularForm.$pristine = false;
  }
};

var viewModelDateComparison = function(scope, ctrl) {
  var modelDate = (ctrl.$modelValue != undefined) ? moment(ctrl.$modelValue) : null;
  var copyDate = (scope.modelCopy[ctrl.$name] != undefined) ? moment(scope.modelCopy[ctrl.$name]) : null;

  if((modelDate && copyDate && (modelDate.diff(copyDate, 'days') == 0)) || (!modelDate && !copyDate)){
    scope.angularForm[scope['formchange_' + ctrl.$name]].$setPristine();
    scope.angularForm[scope['formchange_' + ctrl.$name]].$setUntouched();
    scope.angularForm.$pristine = true;
  } else {
    scope.angularForm[scope['formchange_' + ctrl.$name]].$setDirty();
    scope.angularForm.$pristine = false;
  }
};

var checkForOverallFormPristinity = function(scope, ctrl) {
  // don't do anything before the model and modelCopy are actually initialized
  if (! ('modelCopy' in scope) || ! scope.modelCopy || ! scope.model || ! (scope.model in scope))
    return;

  var modelCopyObject = _.cloneDeep(scope.modelCopy);
  delete modelCopyObject[ctrl.$name];

  var modelObject = _.cloneDeep(scope[scope.model]);
  delete modelObject[ctrl.$name];

  scope.angularForm.$pristine = angular.equals(modelCopyObject, modelObject);

  if (scope.angularForm.$pristine)
    scope.angularForm.$setPristine();
};
