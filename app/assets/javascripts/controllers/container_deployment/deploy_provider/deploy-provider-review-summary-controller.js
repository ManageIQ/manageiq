miqHttpInject(angular.module('miq.containers.providersModule')).controller('containers.deployProviderReviewSummaryController',
  ['$rootScope', '$scope', '$timeout',
  function($rootScope, $scope, $timeout) {
    'use strict';

    var firstShow = true;
    $scope.data.editedInventoryText = '';
    $scope.navTooltip = "";

    $scope.onShow = function () {
      if (firstShow) {
        firstShow = false;
        $scope.data.inventoryText = "";
      }
      $scope.pageShown = true;
      $timeout(function() {
        $scope.pageShown = false;  // done so the next time the page is shown it updates
      });

      $scope.showWaitDialog = true;
      $scope.data.inventoryText = "";
      $scope.data.editedInventoryText = $scope.data.inventoryText;
      //$scope.onInventoryTextChange();
      $scope.showWaitDialog = false;
    };

    $scope.showAdvancedSettings = false;

    $scope.toggleAdvancedSettings = function () {
      $scope.showAdvancedSettings = !$scope.showAdvancedSettings;
    };
  }
]);
