angular.module('miq.wizard').directive('miqWizardStep', function() {
  return {
    restrict: 'A',
    replace: true,
    transclude: true,
    scope: {
      stepTitle: '@',
      stepId: '@',
      stepPriority: '@',
      substeps: '=?',
      nextEnabled: '=?',
      prevEnabled: '=?',
      nextTooltip: '=?',
      prevTooltip: '=?',
      disabled: '@?wzDisabled',
      okToNavAway: '=?',
      description: '@',
      wizardData: '=',
      onShow: '=?',
      showReview: '@?',
      showReviewDetails: '@?',
      reviewTemplate: '@?'
    },
    require: '^miq-wizard',
    templateUrl: '/static/wizard-step.html',
    controller: function ($scope, $timeout) {
      var firstRun = true;
      $scope.steps = [];
      $scope.context = {};
      this.context = $scope.context;

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
      if (angular.isUndefined($scope.showReview)) {
        $scope.showReview = false;
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


      $scope.getEnabledSteps = function() {
        return $scope.steps.filter(function(step){
          return step.disabled !== 'true';
        });
      };

      $scope.getReviewSteps = function() {
        var reviewSteps = $scope.getEnabledSteps().filter(function(step){
          return !angular.isUndefined(step.reviewTemplate);
        });
        return reviewSteps;
      };

      var stepIdx = function(step) {
        var idx = 0;
        var res = -1;
        angular.forEach($scope.getEnabledSteps(), function(currStep) {
          if (currStep === step) {
            res = idx;
          }
          idx++;
        });
        return res;
      };

      $scope.resetNav = function() {
        $scope.goTo($scope.getEnabledSteps()[0]);
      };

      $scope.currentStepNumber = function() {
        //retreive current step number
        return stepIdx($scope.selectedStep) + 1;
      };

      $scope.getStepNumber = function(step) {
        return stepIdx(step) + 1;
      };

      $scope.isNextEnabled = function () {
        var enabled = angular.isUndefined($scope.nextEnabled) || $scope.nextEnabled;
        if ($scope.substeps) {
          angular.forEach($scope.getEnabledSteps(), function(step) {
            enabled = enabled && step.nextEnabled;
          });
        }
        return enabled;
      };

      $scope.isPrevEnabled = function () {
        var enabled = angular.isUndefined($scope.prevEnabled) || $scope.prevEnabled;
        if ($scope.substeps) {
          angular.forEach($scope.getEnabledSteps(), function(step) {
            enabled = enabled && step.prevEnabled;
          });
        }
        return enabled;
      };

      $scope.getStepDisplayNumber = function(step) {
        return $scope.pageNumber +  String.fromCharCode(65 + stepIdx(step)) + ".";
      };

      //watching changes to currentStep
      $scope.$watch('currentStep', function(step) {
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
      $scope.$watch('[editMode, steps.length]', function() {
        var editMode = $scope.editMode;
        if (angular.isUndefined(editMode) || (editMode === null)) {
          return;
        }

        if (editMode) {
          angular.forEach($scope.getEnabledSteps(), function(step) {
            step.completed = true;
          });
        } else {
          var completedStepsIndex = $scope.currentStepNumber() - 1;
          angular.forEach($scope.getEnabledSteps(), function(step, stepIndex) {
            if(stepIndex >= completedStepsIndex) {
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

      $scope.prevStepsComplete = function (nextStep) {
        var nextIdx = stepIdx(nextStep);
        var complete = true;
        angular.forEach($scope.getEnabledSteps(), function (step, stepIndex) {
          if (stepIndex <  nextIdx) {
            complete = complete && step.nextEnabled;
          }
        });
        return complete;
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

      $scope.goTo = function (step) {
        if ($scope.wizardDone) {
          return;
        }

        if (!step.okToNavAway) {
          return;
        }

        if (firstRun || ($scope.getStepNumber(step) < $scope.currentStepNumber() && $scope.selectedStep.prevEnabled) || $scope.prevStepsComplete(step)) {
          unselectAll();

          $scope.selectedStep = step;
          if (step) {
            step.selected = true;

            if (angular.isFunction($scope.selectedStep.onShow)) {
              $scope.selectedStep.onShow();
            }

            watchSelectedStep();

            // Make sure current step is not undefined
            if (!angular.isUndefined($scope.currentStep)) {
              $scope.currentStep = step.wzTitle;
            }

            //emit event upwards with data on goTo() invocation
            if ($scope.selected) {
              $scope.$emit('wizard:stepChanged', {step: step, index: stepIdx(step)});
              firstRun = false;
            }
          }
          $scope.wizard.updateSubStepNumber (stepIdx($scope.selectedStep));
        }
      };

      $scope.$watch('selected', function() {
        if ($scope.selected && $scope.selectedStep) {
          $scope.$emit('wizard:stepChanged', {step: $scope.selectedStep, index: stepIdx( $scope.selectedStep)});
        }
      });

      var stepByTitle = function(titleToFind) {
        var foundStep = null;
        angular.forEach($scope.getEnabledSteps(), function(step) {
          if (step.wzTitle === titleToFind) {
            foundStep = step;
          }
        });
        return foundStep;
      };

      this.addStep = function(step) {
        // Insert the step into step array
        var insertBefore = $scope.steps.find(function(nextStep) {
          return nextStep.stepPriority > step.stepPriority;
        });
        if (insertBefore) {
          $scope.steps.splice($scope.steps.indexOf(insertBefore), 0, step);
        } else {
          $scope.steps.push(step);
        }
      };

      this.currentStepTitle = function(){
        return $scope.selectedStep.wzTitle;
      };

      this.currentStepDescription = function(){
        return $scope.selectedStep.description;
      };

      this.currentStep = function(){
        return $scope.selectedStep;
      };

      this.totalStepCount = function() {
        return $scope.getEnabledSteps().length;
      };

      this.getEnabledSteps = function(){
        return $scope.getEnabledSteps();
      };

      //Access to current step number from outside
      this.currentStepNumber = function(){
        return $scope.currentStepNumber();
      };

      // Allow access to any step
      this.goTo = function(step) {
        var enabledSteps = $scope.getEnabledSteps();
        var stepTo;

        if (angular.isNumber(step)) {
          stepTo = enabledSteps[step];
        } else {
          stepTo = stepByTitle(step);
        }

        $scope.goTo(stepTo);
      };

      // Method used for next button within step
      $scope.next = function(callback) {
        var enabledSteps = $scope.getEnabledSteps();

        // Save the step  you were on when next() was invoked
        var index = stepIdx($scope.selectedStep);

        // Check if callback is a function
        if (angular.isFunction(callback)) {
          if (callback($scope.selectedStep)) {
            if (index === enabledSteps.length - 1) {
              return false;
            } else {
              // Go to the next step
              $scope.goTo(enabledSteps[index + 1]);
              return true;
            }
          } else {
            return true;
          }
        }

        // Completed property set on scope which is used to add class/remove class from progress bar
        $scope.selectedStep.completed = true;

        // Check to see if this is the last step.  If it is next behaves the same as finish()
        if (index === enabledSteps.length - 1) {
          return false;
        } else {
          // Go to the next step
          $scope.goTo(enabledSteps[index + 1]);
          return true;
        }
      };

      $scope.previous = function(callback) {
        var index = stepIdx($scope.selectedStep);

        // Check if callback is a function
        if (angular.isFunction(callback)) {
          if (callback($scope.selectedStep)) {
            if (index === 0) {
              return false;
            } else {
              $scope.goTo($scope.getEnabledSteps()[index - 1]);
              return true;
            }
          }
        }
      };

      if ($scope.substeps && !$scope.onShow) {
        $scope.onShow = function() {
          $timeout(function() {
            if (!$scope.selectedStep) {
              $scope.goTo($scope.getEnabledSteps()[0]);
            } else if ($scope.selectedStep.onShow) {
              $scope.selectedStep.onShow();
            }
          }, 10);
        }
      }
    },
    link: function($scope, $element, $attrs, wizard) {
      $scope.$watch($attrs.ngShow, function(value) {
        $scope.pageNumber = wizard.getStepNumber($scope);
      });
      $scope.title =  $scope.stepTitle;

      $scope.substepsListStyle = {
        'height': wizard.contentHeight,
        'max-height': wizard.contentHeight,
        'overflow-y' : 'auto'
      };
      $scope.contentStyle = wizard.contentStyle;

      wizard.addStep($scope);
      $scope.wizard = wizard;
    }
  };
});
