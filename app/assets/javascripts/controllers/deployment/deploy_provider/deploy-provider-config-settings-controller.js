miqHttpInject(angular.module('miq.containers.providersModule')).controller('containers.deployProviderConfigSettingsController',
  ['$rootScope', '$scope',
  function($rootScope, $scope) {
    'use strict';

    $scope.reviewTemplate = "/static/deploy-provider-config-settings-review.html";
    var firstShow = true;
    $scope.onShow = function () {
      if (firstShow) {
        $scope.data.serverConfigType = 'none';
        $scope.data.configureRouter = true;
        $scope.data.configureRegistry = true;
        $scope.data.configureMetrics = false;
        $scope.data.nfsRegistryServer = '';
        $scope.data.nfsRegistryPath = '';
        $scope.data.nfsMetricsServer = '';
        $scope.data.nfsMetricsPath = '';
        firstShow = false;
      }
      $scope.validateForm();
    };

    var validString = function(value) {
      return angular.isDefined(value) && value.length > 0;
    };

    $scope.validateStorageNode = function() {
      if (angular.isUndefined($scope.data.storageNodes) || $scope.data.storageNodes.length != 1) {
        if ($scope.data.serverConfigType == 'integratedNFS') {
          $scope.data.serverConfigType = 'none';
        }
        return false;
      } else {
        return true;
      }
    };

    $scope.validateInfraNode = function() {
      if (angular.isUndefined($scope.data.infrastructureNodes) || $scope.data.infrastructureNodes.length == 0){
        $scope.data.configureRouter = false;
        return false;
      } else {
        $scope.data.configureRouter = true;
        return true;
      }
    };

    $scope.validateForm = function() {
      $scope.isNfsServer = $scope.data.serverConfigType == 'standardNFS';
      $scope.configStorageComplete = true;
      if ($scope.isNfsServer) {
        if ($scope.data.configureRegistry) {
          if (!validString($scope.data.nfsRegistryServer) || !validString($scope.data.nfsRegistryPath)) {
            $scope.configStorageComplete = false;
          }
        }
        if ($scope.data.configureMetrics) {
          if (!validString($scope.data.nfsMetricsServer) || !validString($scope.data.nfsMetricsPath)) {
            $scope.configStorageComplete = false;
          }
        }
      }
    };
  }
]);
