angular.module('miq.wizard').directive('miqWizardSubstep', function() {
  return {
    restrict: 'A',
    replace: true,
    transclude: true,
    scope: {
      stepTitle: '@',
      stepId: '@',
      nextEnabled: '=?',
      disabled: '@?wzDisabled',
      description: '@',
      wizardData: '='
    },
    require: '^miq-wizard-step',
    templateUrl: '/static/wizard-substep.html',
    controller: function($scope) {
      if (angular.isUndefined($scope.nextEnabled)) {
        $scope.nextEnabled = true;
      }
    },
    link: function($scope, $element, $attrs, step) {
      $scope.title = $scope.stepTitle;
      step.addStep($scope);
    }
  };
});
