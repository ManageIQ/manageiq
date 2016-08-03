miqHttpInject(angular.module('miq.containers.providersModule')).controller('containers.deployProviderCDNChannelController',
  ['$rootScope', '$scope', 'miqService',
  function($rootScope, $scope, miqService) {
    'use strict';

    $scope.reviewTemplate = "/static/deploy_containers_provider/deploy-provider-details-cdn-review.html.haml";
    var firstShow = true;
    $scope.onCdnShow = function () {
      if (firstShow) {
        $scope.data.cdnEnabled = false;
        $scope.data.rhnUsername = '';
        $scope.data.rhnPassword = '';
        $scope.data.rhnSKU = '';
        $scope.data.specifySatelliteUrl = false;
        $scope.data.rhnSatelliteUrl = '';
        firstShow = false;
        $scope.validateForm();
      }
    };

    var validString = function(value) {
      return angular.isDefined(value) && value.length > 0;
    };

    $scope.validateForm = function() {
      $scope.deploymentDetailsCDNComplete = !$scope.data.cdnEnabled || validString($scope.data.rhnUsername) &&
        validString($scope.data.rhnPassword) &&
        validString($scope.data.rhnSKU) &&
        (!$scope.data.specifySatelliteUrl || validString($scope.data.rhnSatelliteUrl));
    };

    $scope.cdnChange = function() {
      if ($scope.data.cdnEnabled) {
        miqService.dynamicAutoFocus('rhn-user-name');
      }
      $scope.validateForm();
    }
  }
]);
