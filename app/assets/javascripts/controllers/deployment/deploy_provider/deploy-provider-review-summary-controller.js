miqHttpInject(angular.module('miq.containers.providersModule')).controller('containers.deployProviderReviewSummaryController',
  ['$rootScope', '$scope', '$timeout', '$document',
  function($rootScope, $scope, $timeout, $document) {
    'use strict';

    var firstShow = true;
    $scope.data.editedPlaybookText = '';
    $scope.navTooltip = "";

    $scope.onShow = function () {
      if (firstShow) {
        firstShow = false;
        $scope.data.playbookText = "";
      }
      $scope.pageShown = true;
      $timeout(function() {
        $scope.pageShown = false;  // done so the next time the page is shown it updates
      });

      // Simulate retrieving playbook text
      $scope.showWaitDialog = true;
      $timeout(function() {
        $scope.data.playbookText = "Text of the playbook goes here.\n\n" +
          "Cancel/save are disabled until the text is actually edited.\n\n" +
          "Once the playbook contents are edited, cancel/save are enabled and the back/deploy buttons are disabled.";
        $scope.data.editedPlaybookText = $scope.data.playbookText;
        $scope.onPlaybookTextChange();
        $scope.showWaitDialog = false;
      }, 2000);
    };

    $scope.showAdvancedSettings = false;

    $scope.toggleAdvancedSettings = function () {
      $scope.showAdvancedSettings = !$scope.showAdvancedSettings;
    };

    $scope.onPlaybookTextChange = function () {
      $scope.playbookChanged = $scope.data.editedPlaybookText != $scope.data.playbookText;
      $scope.okToNavAway = !$scope.playbookChanged;

      if ($scope.playbookChanged) {
        $scope.navTooltip = "Save or cancel playbook changes before leaving this step"
      } else {
        $scope.navTooltip = "";
      }
    };

    $scope.cancelPlaybookChanges = function() {
      $scope.data.editedPlaybookText = $scope.data.playbookText;
      $scope.onPlaybookTextChange();
    }

    $scope.savePlaybookChanges = function() {
      $scope.data.playbookText = $scope.data.editedPlaybookText;
      $scope.onPlaybookTextChange();
    }
  }
]);
