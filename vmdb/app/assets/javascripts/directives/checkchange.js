cfmeAngularApplication.directive('checkchange', function() {
  return {
    require: 'ngModel',
      link: function (scope, elem, attr, ctrl) {
        if(scope.skipCheck == undefined)
          scope.skipCheck = new Object();
        if(attr.checkchange != "" && !scope.skipCheck.hasOwnProperty(ctrl.$name))
          scope.skipCheck[ctrl.$name] = attr.checkchange.split(',');

        ctrl.$parsers.unshift(function() {
          scope.miqService.miqFlashClear();

          scope.ctrl = ctrl;

          for (var name in scope.modelCopy) {
            if(ctrl.$name == name) {
              if(typeof (ctrl.$viewValue) == "boolean") {
                int_value = parseInt(scope.modelCopy[name], 10);
                var bool_value = int_value != 0 ? true : false;
                if(ctrl.$viewValue == bool_value) {
                  scope.form[name].$setPristine(true);
                  break;
                }
              } else {
                if (ctrl.$viewValue == scope.modelCopy[name]) {
                  scope.form[name].$setPristine(true);
                  break;
                }
              }
            }
          }

          if(scope.form[ctrl.$name].$pristine) {
            scope.form.$pristine = true;
            for (var name in scope.form) {
              if (ctrl.$name != name && scope.modelCopy[name] != scope.form[name].$modelValue) {
                if (scope.skipCheck[ctrl.$name] == undefined || scope.skipCheck[ctrl.$name].indexOf(name) == -1) {
                  scope.form.$pristine = false;
                  break;
                }
              }
            }
          } else {
            scope.form.$pristine = false;
          }
          if(scope.form.$pristine)
            scope.form.$setPristine(true);
        });

        ctrl.$parsers.push(function(updatedModelValue) {
          if (updatedModelValue === undefined || scope.form[ctrl.$name].$modelValue === undefined) {
            return ctrl.$viewValue;
          }
        });
      }
  }
});
