angular.module('miq.wizard').directive('miqWizardSubstep', function() {
  return {
    restrict: 'A',
    replace: true,
    transclude: true,
    scope: {
      stepTitle: '@',
      stepId: '@',
      stepPriority: '@',
      nextEnabled: '=?',
      prevEnabled: '=?',
      nextTooltip: '=?',
      prevTooltip: '=?',
      okToNavAway: '=?',
      disabled: '@?wzDisabled',
      description: '@',
      wizardData: '=',
      onShow: '=?',
      showReviewDetails: '@?',
      reviewTemplate: '@?'
    },
    require: '^miq-wizard-step',
    templateUrl: '/static/wizard-substep.html',
    controller: function($scope) {
      if (angular.isUndefined($scope.nextEnabled)) {
        $scope.nextEnabled = true;
      }
      if (angular.isUndefined($scope.prevEnabled)) {
        $scope.prevEnabled = true;
      }
      if (angular.isUndefined($scope.nextTooltip)) {
        $scope.nextEnabled = true;
      }
      if (angular.isUndefined($scope.prevToolitp)) {
        $scope.prevEnabled = true;
      }
      if (angular.isUndefined($scope.showReviewDetails)) {
        $scope.showReviewDetails = false;
      }
      if (angular.isUndefined($scope.stepPriority)) {
        $scope.stepPriority = 999;
      } else {
        $scope.stepPriority = parseInt($scope.stepPriority);
      }
      if (angular.isUndefined($scope.okToNavAway)) {
        $scope.okToNavAway = true;
      }

      $scope.isPrevEnabled = function () {
        var enabled = angular.isUndefined($scope.prevEnabled) || $scope.prevEnabled;
        if ($scope.substeps) {
          angular.forEach($scope.getEnabledSteps(), function(step) {
            enabled = enabled && step.prevEnabled;
          });
        }
        return enabled;
      };

    },
    link: function($scope, $element, $attrs, step) {
      $scope.title = $scope.stepTitle;
      step.addStep($scope);
    }
  };
});
