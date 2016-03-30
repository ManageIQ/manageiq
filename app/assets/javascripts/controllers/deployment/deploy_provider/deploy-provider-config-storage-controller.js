miqHttpInject(angular.module('miq.containers.providersModule')).controller('containers.deployProviderConfigStorageController',
  ['$rootScope', '$scope', '$timeout', '$document',
  function($rootScope, $scope, $timeout, $document) {
    'use strict';

    $scope.reviewTemplate = "/static/deploy-provider-config-storage-review.html";

    var firstShow = true;
    $scope.onShow = function () {
      if (firstShow) {
        $scope.data.storageType = 'none';
        $scope.data.nfsStorageServer = '';
        $scope.data.nfsStoragePath = '';
        firstShow = false;
      }
      $scope.validateForm();

      $timeout(function() {
        if ($scope.data.storageType == 'nfs') {
          var queryResult = $document[0].getElementById('nfs-storage-server');
          queryResult.focus();
        }
      }, 200);
    };

    var validString = function(value) {
      return angular.isDefined(value) && value.length > 0;
    };

    $scope.validateForm = function() {
      $scope.configStorageComplete =
        $scope.data.storageType !== 'nfs' ||
        (validString($scope.data.nfsStorageServer) &&
         validString($scope.data.nfsStoragePath));
    };
  }
]);
