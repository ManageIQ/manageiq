ManageIQ.angularApplication.directive('autoFocus', ['$timeout', function($timeout) {
  return {
    require: 'ngModel',
    link: function (scope, elem, attr, ctrl) {
      scope['form_focus_' + ctrl.$name] = elem[0];

      scope.$watch(scope['afterGet'], function() {
        $timeout(function(){
          angular.element(scope['form_focus_' + ctrl.$name]).focus();
        }, 0);
      });
    }
  }
}]);