miqHttpInject(angular.module('miq.containers.providersModule')).controller('containers.deployProviderCDNChannelController',
  ['$rootScope', '$scope', '$timeout', '$document',
  function($rootScope, $scope, $timeout, $document) {
    'use strict';

    $scope.reviewTemplate = "/static/deploy-provider-details-cdn-review.html";
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
      $timeout(function() {
        if ($scope.data.cdnEnabled) {
          var queryResult = $document[0].getElementById('rhn-user-name');
          queryResult.focus();
        }
      }, 200);
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
  }
]);
