miqHttpInject(angular.module('miq.containers.providersModule')).controller('containers.deployProviderReviewSummaryController',
  ['$rootScope', '$scope', '$timeout', '$document',
  function($rootScope, $scope, $timeout, $document) {
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

      // $scope.data.review_inventory = true;
      $scope.showWaitDialog = true;
      $timeout(function() {
        //var url = '/api/container_deployments';
        //$http.post(url, {"action" : "start", "resource" :  $scope.data}).success(function (response) {
          //'use strict';
          //$scope.data.playbookText = response.results[0].data.inventory;
        //});
        //$scope.data.editedPlaybookText = $scope.data.playbookText;
        $scope.data.inventoryText = "Text of the Inventory goes here";
        $scope.data.editedInventoryText = $scope.data.inventoryText;
        //$scope.onInventoryTextChange();
        $scope.showWaitDialog = false;
      }, 2000);
    };

    $scope.showAdvancedSettings = false;

    $scope.toggleAdvancedSettings = function () {
      $scope.showAdvancedSettings = !$scope.showAdvancedSettings;
    };
  }
]);
