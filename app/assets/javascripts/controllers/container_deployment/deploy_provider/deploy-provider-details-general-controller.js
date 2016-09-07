miqHttpInject(angular.module('miq.containers.providersModule')).controller('containers.deployProviderDetailsGeneralController',
  ['$rootScope', '$scope', 'miqService',
  function($rootScope, $scope, miqService) {
    'use strict';

    $scope.reviewTemplate = "/static/deploy_containers_provider/deploy-provider-details-general-review.html.haml";

    var firstShow = true;
    $scope.onShow = function () {
      if (firstShow) {
        $scope.existingProviders = [];
        $scope.data.existingProviders.forEach(function(provider){
          $scope.existingProviders.push({
            id: provider.provider.id,
            name: provider.provider.name
          })
        });
        if (angular.isDefined($scope.existingProviders) && $scope.existingProviders.length > 0) {
          $scope.data.existingProviderId = $scope.existingProviders[0].id;
          $scope.data.existingProvider = $scope.existingProviders[0];
        }

        $scope.newVmProviders = [];
        $scope.data.newVmProviders.forEach(function (provider) {
          $scope.newVmProviders.push({
            id: provider.provider.id,
            name: provider.provider.name
          })
        });
        if (angular.isDefined($scope.newVmProviders) && $scope.newVmProviders.length > 0) {
          $scope.data.newVmProviderId = $scope.newVmProviders[0].id;
          $scope.data.newVmProvider = $scope.newVmProviders[0];
        }

        $scope.deploymentDetailsGeneralComplete = false;
        firstShow = false;
        miqService.dynamicAutoFocus('new-provider-name');
      }
    };
    $scope.updateProviderName = function() {
      $scope.deploymentDetailsGeneralComplete = angular.isDefined($scope.data.providerName) && $scope.data.providerName.length > 0;
    };
  }
]);
