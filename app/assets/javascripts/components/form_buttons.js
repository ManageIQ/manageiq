ManageIQ.angular.app.directive('formButtons', function() {
  return {
    restrict: 'E',
    scope: false,
    controller: 'buttonGroupController',
    templateUrl: '/static/buttons.html'
  };
});
