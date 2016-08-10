ManageIQ.angular.app.directive('formButtons', function() {
  return {
    restrict: 'E',
    scope: false,
    controller: 'buttonGroupController',
    templateUrl: '/static/shared_components/form_buttons.html'
  };
});
