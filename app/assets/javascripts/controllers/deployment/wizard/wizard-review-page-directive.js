angular.module('miq.wizard').directive('miqWizardReviewPage', function() {
  return {
    restrict: 'A',
    replace: true,
    scope: {
      shown: '=',
      wizardData: "="
    },
    require: '^miq-wizard',
    templateUrl: '/static/wizard-review-page.html',
    controller: function ($scope) {
      $scope.toggleShowReviewDetails = function (step) {
        if (step.showReviewDetails === true) {
          step.showReviewDetails = false;
        } else {
          step.showReviewDetails = true;
        }
      };
      $scope.getSubStepNumber = function (step, substep) {
        return step.getStepDisplayNumber(substep);
      };
      $scope.getReviewSubSteps = function (reviewStep) {
        var substeps = reviewStep.getReviewSteps();
        console.log("Step " + reviewStep.stepTitle + " has " + substeps.length + " steps");
        return substeps;
      };
      $scope.reviewSteps = [];
      $scope.updateReviewSteps = function (wizard) {
        $scope.reviewSteps = wizard.getReviewSteps();
      };
    },
    link: function($scope, $element, $attrs, wizard) {
      $scope.$watch('shown', function (value) {
        if (value) {
          $scope.updateReviewSteps(wizard);
        }
      });
    }
  };
});
