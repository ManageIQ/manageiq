angular.module('miq.wizard').directive('miqWizardSubstep', function() {
  return {
    restrict: 'A',
    replace: true,
    transclude: true,
    scope: {
      stepTitle: '@',
      canenter : '=',
      canexit : '=',
      disabled: '@?wzDisabled',
      description: '@',
      wizardData: '='
    },
    require: '^miq-wizard-step',
    templateUrl: '/static/wizard-substep.html',
    controller: function($scope) {
    },
    link: function($scope, $element, $attrs, step) {
      $scope.title = $scope.stepTitle;
      step.addStep($scope);
    }
  };
});
