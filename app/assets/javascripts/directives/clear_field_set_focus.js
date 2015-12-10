ManageIQ.angular.app.directive('clearFieldSetFocus', ['$timeout', 'miqService', function($timeout, miqService) {
  return {
    require: 'ngModel',
    link: function (scope, elem, attr, ctrl) {
      scope['form_passwordfocus_' + ctrl.$name] = elem[0];

      var option = attr.clearFieldSetFocus;

      scope.$watch('bChangeStoredPassword', function(value) {
        if (value) {
          $timeout(function () {
            scope[scope.model][ctrl.$name] = '';
            if(option != "no-focus")
              angular.element(scope['form_passwordfocus_' + ctrl.$name]).focus();
          }, 0);
        }
      });

      scope.$watch('bCancelPasswordChange', function(value) {
        if (value) {
          $timeout(function () {
            scope[scope.model][ctrl.$name] = miqService.storedPasswordPlaceholder;
          }, 0);
        }
      });
    }
  }
}]);
