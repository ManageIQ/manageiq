angular.module('miq.wizard').directive('miqWizardStep', function() {
  return {
    restrict: 'A',
    replace: true,
    transclude: true,
    scope: {
      stepTitle: '@',
      stepId: '@',
      substeps: '=?',
      nextEnabled: '=?',
      disabled: '@?wzDisabled',
      description: '@',
      wizardData: '='
    },
    require: '^miq-wizard',
    templateUrl: '/static/wizard-step.html',
    controller: function ($scope) {
      var firstRun = true;
      $scope.steps = [];
      $scope.context = {};
      this.context = $scope.context;

      $scope.getEnabledSteps = function() {
        return $scope.steps.filter(function(step){
          return step.disabled !== 'true';
        });
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

      if (!$scope.substeps && angular.isUndefined($scope.nextEnabled)) {
        $scope.nextEnabled = true;
      }

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

      $scope.goTo = function (step) {
        if (firstRun || $scope.getStepNumber(step) < $scope.currentStepNumber() || $scope.nextEnabled) {
          unselectAll();

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
          if ($scope.selected) {
            $scope.$emit('wizard:stepChanged', {step: step, index: stepIdx(step)});
            firstRun = false;
          }
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
        // Push the step onto step array
        $scope.steps.push(step);

        if ($scope.getEnabledSteps().length === 1) {
          $scope.goTo($scope.getEnabledSteps()[0]);
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
    }
  };
});
