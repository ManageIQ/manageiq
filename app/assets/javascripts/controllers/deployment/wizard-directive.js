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
      wizardDone: '=?'
    },
    templateUrl: '/static/wizard.html',
    controller: function ($scope) {
      var firstRun = true;
      $scope.steps = [];
      $scope.context = {};
      this.context = $scope.context;

      $scope.nextEnabled = false;

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
      $scope.getEnabledSteps = function () {
        return $scope.steps.filter(function (step) {
          return step.disabled !== 'true';
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
        //retreive current step number
        return stepIdx($scope.selectedStep) + 1;
      };

      $scope.getStepNumber = function (step) {
        return stepIdx(step) + 1;
      };

      $scope.$watch('wizardDone', function (value) {
        this.wizardDone = value;
      });

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

      $scope.goTo = function (step, resetStepNav) {
        if ($scope.wizardDone) {
          return;
        }

        if (firstRun || $scope.getStepNumber(step) < $scope.currentStepNumber() || $scope.nextEnabled) {
          unselectAll();

          if (!firstRun && resetStepNav && step.substeps) {
            step.resetNav();
          }

          $scope.selectedStep = step;
          step.selected = true;

          // Watch the new step for next button enabled status (remove any previous watcher)
          if ($scope.stepEnabledWatcher) {
            $scope.stepEnabledWatcher();
          }
          $scope.stepEnabledWatcher = $scope.$watch('selectedStep.nextEnabled', function (value) {
            $scope.nextEnabled = value;
          });

          // Make sure current step is not undefined
          if (!angular.isUndefined($scope.currentStep)) {
            $scope.currentStep = step.wzTitle;
          }

          //emit event upwards with data on goTo() invoktion
          if (!step.substeps) {
            $scope.$emit('wizard:stepChanged', {step: step, index: stepIdx(step)});
          }
          firstRun = false;
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
        // Push the step onto step array
        $scope.steps.push(step);

        if ($scope.getEnabledSteps().length === 1) {
          $scope.goTo($scope.getEnabledSteps()[0]);
        }
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
              $scope.goTo(enabledSteps[index + 1]);
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
    }
  };
});
