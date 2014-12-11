cfmeAngularApplication.directive('checkchange', function() {
  return {
    require: 'ngModel',
      link: function (scope, elem, attrs, ctrl) {
        ctrl.$parsers.unshift(function() {
          for (var name in scope.modelCopy) {
            if(ctrl.$name == name) {
              if(ctrl.$viewValue == scope.modelCopy[name]) {
                  scope.form[name].$setPristine(true);
                  break;
              }
            }
          }

          if(scope.form[ctrl.$name].$pristine) {
            scope.form.$pristine = true;
            for (var name in scope.form) {
              if (scope.form[name].$pristine === false) {
                scope.form.$pristine = false;
                break;
              }
            }
          } else {
            scope.form.$pristine = false;
          }
          if(scope.form.$pristine)
            scope.form.$setPristine(true);
        });
      }
  }
});
