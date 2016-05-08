miqHttpInject(angular.module('miq.containers.providersModule', ['ui.bootstrap', 'patternfly', 'miq.dialogs', 'miq.wizard'])).controller('containers.deployProviderController',
  ['$rootScope', '$scope', '$timeout', '$http',
  function($rootScope, $scope, $timeout, $http) {
    'use strict';

    $scope.data = {};
    $scope.nodeData = {
      allNodes: [],
      filteredNodes: [],
      providerVMs: [],
      newVMs: [],
      userDefinedVMs: []
    };

    var initializeDeploymentWizard = function () {
      $scope.deployProviderReady = false;
      $scope.deployComplete = false;
      $scope.deployInProgress = false;
      $scope.deploySuccess = false;
      $scope.deployFailed = false;

      $scope.data = {
        providerName: '',
        providerType: 'openshiftOrigin',
        provisionOn: 'existingVms',
        masterCount: 0,
        nodeCount: 0,
        infraNodeCount: 0,
        cdnConfigType: 'satellite',
        authentication: {
          mode: 'all'
        }
      };

      $timeout(function() {
        $scope.data.existingProviders = $scope.deploymentData.providers;
        $scope.data.newVmProviders = $scope.deploymentData.provision;
        $scope.deployProviderReady = true;
      }, 5000);

      $scope.deploymentDetailsGeneralComplete = false;
      $scope.deployComplete = false;
      $scope.deployInProgress = false;
      $scope.nextButtonTitle = "Next >";
    };

    $scope.ready = false;
    var url = '/api/container_deployments';
    $http.post(url, {"action" : "collect_data", "resource" : "none"}).success(function (response) {
      'use strict';

      $scope.deploymentData = response.results[0].data;
      initializeDeploymentWizard();
      $scope.ready = true;
    });

    $scope.data = {};
    $scope.deployComplete = false;
    $scope.deployInProgress = false;

    var startDeploy = function () {
      $scope.deployInProgress = true;
      $timeout(function () {
        var url = '/api/container_deployments';
        $http.post(url, {"action" : "start", "resource" :  $scope.data}).success(function (response) {
          'use strict';
          $scope.deployInProgress = true;
          debugger;
          var automationID = response
        });

        if ($scope.deployInProgress) {
          $scope.deployInProgress = false;
          $scope.deployComplete = false;
          $scope.deploySuccess = false;
          $scope.deployFailed = false;
          $scope.deployFailureMessage = "An unknown error has occurred.";
        }
      }, 5000);
    };

    $scope.nextCallback = function(step) {
      if (step.stepId === 'review-summary') {
        startDeploy();
      }
      return true;
    };
    $scope.backCallback = function(step) {
      return true;
    };

    $scope.$on("wizard:stepChanged", function(e, parameters) {
      if (parameters.step.stepId == 'review-summary') {
        $scope.nextButtonTitle = "Deploy";
      } else if (parameters.step.stepId == 'review-progress') {
        $scope.nextButtonTitle = "Close";
      } else {
        $scope.nextButtonTitle = "Next >";
      }
    });


    $scope.showDeploymentWizard = false;
    var showListener =  function() {
      if (!$scope.showDeploymentWizard) {
        initializeDeploymentWizard();
        $scope.showDeploymentWizard = true;
      }
    };
    $rootScope.$on('deployProvider.show', showListener);

    $scope.cancelDeploymentWizard = function () {
      if (!$scope.deployInProgress) {
        $scope.showDeploymentWizard = false;
      }
    };

    $scope.$on('$destroy', showListener);


    $scope.cancelWizard = function () {
      $scope.showDeploymentWizard = false;
      return true;
    };

    $scope.finishedWizard = function () {
      $rootScope.$emit('deployProvider.finished');
      $scope.showDeploymentWizard = false;
      return true;
    };
  }
]);
