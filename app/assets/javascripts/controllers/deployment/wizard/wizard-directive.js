angular.module('miq.wizard').directive('miqWizard', function () {
  'use strict';
  return {
    restrict: 'A',
    transclude: true,
    replace: true,
    scope: {
      visible: '=',
      title: '@',
      modalSize: '@',
      contentHeight: '@?',
      hideIndicators: '=?',
      currentStep: '=',
      cancelTitle: '=?',
      backTitle: '=?',
      nextTitle: '=?',
      backCallback: '=?',
      nextCallback: '=?',
      onFinish: '&',
      onCancel: '&',
      wizardReady: '=?',
      wizardDone: '=?'
    },
    templateUrl: '/static/wizard.html',
    controller: function ($scope, $timeout) {
      var firstRun = true;
      $scope.steps = [];
      $scope.context = {};
      this.context = $scope.context;

      if (angular.isUndefined($scope.wizardReady)) {
        $scope.wizardReady = true;
      }

      $scope.nextEnabled = false;
      $scope.prevEnabled = false;

      if (!$scope.cancelTitle) {
        $scope.cancelTitle = "Cancel";
      }
      if (!$scope.backTitle) {
        $scope.backTitle = "< Back";
      }
      if (!$scope.nextTitle) {
        $scope.nextTitle = "Next >";
      }

      if (!$scope.contentHeight) {
        $scope.contentHeight = '300px';
      }
      this.contentHeight = $scope.contentHeight;
      this.contentStyle = {
        'height': $scope.contentHeight,
        'max-height': $scope.contentHeight,
        'overflow-y': 'auto'
      };
      $scope.contentStyle = this.contentStyle;

      $scope.getEnabledSteps = function () {
        return $scope.steps.filter(function (step) {
          return step.disabled !== 'true';
        });
      };

      this.getReviewSteps = function() {
        return $scope.steps.filter(function(step){
          return !step.disabled &&
            (!angular.isUndefined(step.reviewTemplate) || step.getReviewSteps().length > 0);
        });
      };

      var stepIdx = function (step) {
        var idx = 0;
        var res = -1;
        angular.forEach($scope.getEnabledSteps(), function (currStep) {
          if (currStep === step) {
            res = idx;
          }
          idx++;
        });
        return res;
      };

      $scope.currentStepNumber = function () {
        //retrieve current step number
        return stepIdx($scope.selectedStep) + 1;
      };

      $scope.getStepNumber = function (step) {
        return stepIdx(step) + 1;
      };

      //watching changes to currentStep
      $scope.$watch('currentStep', function (step) {
        //checking to make sure currentStep is truthy value
        if (!step) {
          return;
        }

        //setting stepTitle equal to current step title or default title
        var stepTitle = $scope.selectedStep.wzTitle;
        if ($scope.selectedStep && stepTitle !== $scope.currentStep) {
          $scope.goTo(stepByTitle($scope.currentStep));
        }
      });

      //watching steps array length and editMode value, if edit module is undefined or null the nothing is done
      //if edit mode is truthy, then all steps are marked as completed
      $scope.$watch('[editMode, steps.length]', function () {
        var editMode = $scope.editMode;
        if (angular.isUndefined(editMode) || (editMode === null)) {
          return;
        }

        if (editMode) {
          angular.forEach($scope.getEnabledSteps(), function (step) {
            step.completed = true;
          });
        } else {
          var completedStepsIndex = $scope.currentStepNumber() - 1;
          angular.forEach($scope.getEnabledSteps(), function (step, stepIndex) {
            if (stepIndex >= completedStepsIndex) {
              step.completed = false;
            }
          });
        }
      }, true);

      var unselectAll = function () {
        //traverse steps array and set each "selected" property to false
        angular.forEach($scope.getEnabledSteps(), function (step) {
          step.selected = false;
        });
        //set selectedStep variable to null
        $scope.selectedStep = null;
      };

      var watchSelectedStep = function () {
        // Remove any previous watchers
        if ($scope.nextStepEnabledWatcher) {
          $scope.nextStepEnabledWatcher();
        }
        if ($scope.nextStepTooltipWatcher) {
          $scope.nextStepTooltipWatcher();
        }
        if ($scope.prevStepEnabledWatcher) {
          $scope.prevStepEnabledWatcher();
        }
        if ($scope.preStepTooltipWatcher) {
          $scope.prevStepTooltipWatcher();
        }

        // Add watchers for the selected step
        $scope.nextStepEnabledWatcher = $scope.$watch('selectedStep.nextEnabled', function (value) {
          $scope.nextEnabled = value;
        });
        $scope.nextStepTooltipWatcher = $scope.$watch('selectedStep.nextTooltip', function (value) {
          $scope.nextTooltip = value;
        });
        $scope.prevStepEnabledWatcher = $scope.$watch('selectedStep.prevEnabled', function (value) {
          $scope.prevEnabled = value;
        });
        $scope.prevStepTooltipWatcher = $scope.$watch('selectedStep.prevTooltip', function (value) {
          $scope.prevTooltip = value;
        });
      };

      $scope.goTo = function (step, resetStepNav) {
        if ($scope.wizardDone || ($scope.selectedStep && !$scope.selectedStep.okToNavAway) || step === $scope.selectedStep) {
          return;
        }

        if (firstRun || ($scope.getStepNumber(step) < $scope.currentStepNumber() && $scope.selectedStep.isPrevEnabled()) || $scope.selectedStep.isNextEnabled()) {
          unselectAll();

          if (!firstRun && resetStepNav && step.substeps) {
            step.resetNav();
          }

          $scope.selectedStep = step;
          step.selected = true;

          $timeout(function() {
            if (angular.isFunction(step.onShow)) {
              step.onShow();
            }
          }, 100);

          watchSelectedStep();

          // Make sure current step is not undefined
          if (!angular.isUndefined($scope.currentStep)) {
            $scope.currentStep = step.wzTitle;
          }

          //emit event upwards with data on goTo() invocation
          if (!step.substeps) {
            $scope.$emit('wizard:stepChanged', {step: step, index: stepIdx(step)});
          }
          firstRun = false;
        }

        if (!$scope.selectedStep.substeps) {
          $scope.firstStep =  stepIdx($scope.selectedStep) === 0;
        } else {
          $scope.firstStep = stepIdx($scope.selectedStep) === 0 && $scope.selectedStep.currentStepNumber() === 1;
        }
      };

      $scope.stepClick = function (step) {
        if (step.allowClickNav) {
          $scope.goTo(step, true);
        }
      };

      var stepByTitle = function (titleToFind) {
        var foundStep = null;
        angular.forEach($scope.getEnabledSteps(), function (step) {
          if (step.wzTitle === titleToFind) {
            foundStep = step;
          }
        });
        return foundStep;
      };

      this.addStep = function (step) {
        // Insert the step into step array
        var insertBefore = $scope.steps.find(function(nextStep) {
          return nextStep.stepPriority > step.stepPriority;
        });
        if (insertBefore) {
          $scope.steps.splice($scope.steps.indexOf(insertBefore), 0, step);
        } else {
          $scope.steps.push(step);
        }

        if ($scope.wizardReady && ($scope.getEnabledSteps().length > 0) && (step == $scope.getEnabledSteps()[0])) {
          $scope.goTo($scope.getEnabledSteps()[0]);
        }
      };

      this.isWizardDone = function() {
        return $scope.wizardDone;
      };

      this.updateSubStepNumber = function (value) {
        $scope.firstStep =  stepIdx($scope.selectedStep) === 0 && value === 0;
      };

      this.currentStepTitle = function () {
        return $scope.selectedStep.wzTitle;
      };

      this.currentStepDescription = function () {
        return $scope.selectedStep.description;
      };

      this.currentStep = function () {
        return $scope.selectedStep;
      };

      this.totalStepCount = function () {
        return $scope.getEnabledSteps().length;
      };

      this.getEnabledSteps = function () {
        return $scope.getEnabledSteps();
      };

      //Access to current step number from outside
      this.currentStepNumber = function () {
        return $scope.currentStepNumber();
      };

      this.getStepNumber = function (step) {
        return $scope.getStepNumber(step);
      };

      // Allow access to any step
      this.goTo = function (step, resetStepNav) {
        var enabledSteps = $scope.getEnabledSteps();
        var stepTo;

        if (angular.isNumber(step)) {
          stepTo = enabledSteps[step];
        } else {
          stepTo = stepByTitle(step);
        }

        $scope.goTo(stepTo, resetStepNav);
      };

      // Method used for next button within step
      this.next = function (callback) {
        var enabledSteps = $scope.getEnabledSteps();

        // Save the step  you were on when next() was invoked
        var index = stepIdx($scope.selectedStep);

        if ($scope.selectedStep.substeps) {
          if ($scope.selectedStep.next(callback)) {
            return;
          }
        }

        // Check if callback is a function
        if (angular.isFunction(callback)) {
          if (callback($scope.selectedStep)) {
            if (index === enabledSteps.length - 1) {
              this.finish();
            } else {
              // Go to the next step
              if (enabledSteps[index + 1].substeps) {
                enabledSteps[index + 1].resetNav();
              }
            }
          } else {
            return;
          }
        }

        // Completed property set on scope which is used to add class/remove class from progress bar
        $scope.selectedStep.completed = true;

        // Check to see if this is the last step.  If it is next behaves the same as finish()
        if (index === enabledSteps.length - 1) {
          this.finish();
        } else {
          // Go to the next step
          $scope.goTo(enabledSteps[index + 1]);
        }
      };

      this.previous = function (callback) {
        var index = stepIdx($scope.selectedStep);

        if ($scope.selectedStep.substeps) {
          if ($scope.selectedStep.previous(callback)) {
            return;
          }
        }

        // Check if callback is a function
        if (angular.isFunction(callback)) {
          if (callback($scope.selectedStep)) {
            if (index === 0) {
              throw new Error("Can't go back. It's already in step 0");
            } else {
              $scope.goTo($scope.getEnabledSteps()[index - 1]);
            }
          }
        }
      };

      this.finish = function () {
        if ($scope.onFinish) {
          if ($scope.onFinish() !== false) {
            this.reset();
          }
        }
      };

      this.cancel = function () {
        if ($scope.onCancel) {
          if ($scope.onCancel() !== false) {
            this.reset();
          }
        }
      };

      //reset
      this.reset = function () {
        //traverse steps array and set each "completed" property to false
        angular.forEach($scope.getEnabledSteps(), function (step) {
          step.completed = false;
        });
        //go to first step
        this.goTo(0);
      };
    },
    link: function($scope, $element, $attrs) {
      $scope.$watch('wizardReady', function () {
        if ($scope.wizardReady) {
          $scope.goTo($scope.getEnabledSteps()[0]);
        }
      });
    }
  };
});
