miqHttpInject(angular.module('miq.containers.providersModule')).controller('containers.deployProviderConfigSettingsController',
  ['$rootScope', '$scope', '$timeout', '$document',
  function($rootScope, $scope, $timeout, $document) {
    'use strict';

    $scope.reviewTemplate = "/static/deploy-provider-config-settings-review.html";
    var firstShow = true;
    $scope.onShow = function () {
      if (firstShow) {
        $scope.data.configureRouter = false;
        $scope.data.configureRegistry = false;
        $scope.data.useDefaultRegistry = false;
        $scope.data.useS3Registry = false;
        $scope.data.useSwift = false;
        $scope.data.configureMetrics = false;
        firstShow = false;
      }
      $scope.validateForm();

      $timeout(function() {
        var queryResult = $document[0].getElementById('rhn-user-name');
        queryResult.focus();
      }, 200);
    };

    var validString = function(value) {
      return angular.isDefined(value) && value.length > 0;
    };

    $scope.validateForm = function() {
      $scope.configStorageComplete =
        $scope.data.storageType !== 'nfs' ||
        (validString($scope.data.nfsStorageUsername) &&
         validString($scope.data.nfsStoragePassword) &&
         validString($scope.data.nfsStorageUrl));
    };
  }
]);
