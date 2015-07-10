miqAngularApplication.directive('checkchange', function() {
  return {
    require: 'ngModel',
    link: function (scope, elem, attr, ctrl) {
      scope['formchange_' + ctrl.$name] = elem[0].name
      scope['elemType_' + ctrl.$name] = attr.type;

      scope.$watch(attr.ngModel, function() {
        if(ctrl.$viewValue != undefined) {
          if(scope['elemType_' + ctrl.$name] != "date") {
            viewModelComparison(scope, ctrl);
          }
          else {
            viewModelDateComparison(scope, ctrl);
          }
        }
        if(scope.angularForm.$pristine )
          checkForOverallFormPristinity(scope, ctrl);
      });

      ctrl.$parsers.push(function(value) {
        scope.miqService.miqFlashClear();

        if (value == scope.modelCopy[ctrl.$name]) {
          scope.angularForm[scope['formchange_' + ctrl.$name]].$setPristine(true);
        }
        if(scope.angularForm[scope['formchange_' + ctrl.$name]].$pristine) {
          checkForOverallFormPristinity(scope, ctrl);
        }
        scope.angularForm[scope['formchange_' + ctrl.$name]].$setTouched(true);
        return value;
      });

      if(scope.angularForm.$pristine)
        scope.angularForm.$setPristine(true);
    }
  }
});

var viewModelComparison = function(scope, ctrl) {
  if (ctrl.$viewValue == scope.modelCopy[ctrl.$name]) {
    scope.angularForm[scope['formchange_' + ctrl.$name]].$setPristine(true);
    scope.angularForm[scope['formchange_' + ctrl.$name]].$setUntouched(true);
    scope.angularForm.$pristine = true;
  }
  else {
    scope.angularForm[scope['formchange_' + ctrl.$name]].$setPristine(false);
    scope.angularForm.$pristine = false;
  }
};

var viewModelDateComparison = function(scope, ctrl) {
  var viewValueDate = new Date(ctrl.$viewValue);
  var viewValueDateCmp = viewValueDate.getUTCMonth() + 1 + "/" + viewValueDate.getUTCDate() + "/" + viewValueDate.getUTCFullYear();

  var modelCopyDate = new Date(scope.modelCopy[ctrl.$name]);
  var modelCopyDateCmp = modelCopyDate.getUTCMonth() + 1 + "/" + modelCopyDate.getUTCDate() + "/" + modelCopyDate.getUTCFullYear();

  if(viewValueDateCmp == modelCopyDateCmp) {
    scope.angularForm[scope['formchange_' + ctrl.$name]].$setPristine(true);
    scope.angularForm[scope['formchange_' + ctrl.$name]].$setUntouched(true);
    scope.angularForm.$pristine = true;
  }
  else {
    scope.angularForm[scope['formchange_' + ctrl.$name]].$setPristine(false);
    scope.angularForm.$pristine = false;
  }
};

var checkForOverallFormPristinity = function(scope, ctrl) {
  var modelCopyObject = JSON.parse(JSON.stringify(scope.modelCopy));
  delete modelCopyObject[ctrl.$name];

  var modelObject = JSON.parse(JSON.stringify(scope[scope.model]))
  delete modelObject[ctrl.$name];

  if(JSON.stringify(modelCopyObject) != JSON.stringify(modelObject)) {
    scope.angularForm.$pristine = false;
  }
  else {
    scope.angularForm.$pristine = true;
  }
  if(scope.angularForm.$pristine)
    scope.angularForm.$setPristine(true);
};
