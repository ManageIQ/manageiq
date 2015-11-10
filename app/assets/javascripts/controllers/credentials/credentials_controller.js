ManageIQ.angularApplication.controller('credentialsController', ['$http', '$scope', 'miqService', function($http, $scope, miqService) {
  var init = function() {
    $scope.bChangeStoredPassword = undefined;
    $scope.bCancelPasswordChange = undefined;

    $scope.$on('resetClicked', function(e) {
      $scope.resetClicked();
    });

    $scope.$on('setNewRecord', function(e) {
      $scope.setNewRecord();
    });

    ManageIQ.angularApplication.$credentialsScope = $scope;

    if ($scope.formId == 'new') {
      $scope.newRecord = true;
    }
    else {
      $scope.newRecord = false;
      $scope.bChangeStoredPassword = false;
      $scope.bCancelPasswordChange = false;
    }
  };

  $scope.changeStoredPassword = function() {
    $scope.bChangeStoredPassword = true;
    $scope.bCancelPasswordChange = false;
  };

  $scope.cancelPasswordChange = function() {
    if($scope.bChangeStoredPassword) {
      $scope.bCancelPasswordChange = true;
      $scope.bChangeStoredPassword = false;
    }
  };

  $scope.showVerify = function(userid) {
    return $scope.newRecord || (!$scope.showChangePasswordLinks(userid)) || $scope.bChangeStoredPassword;
  };

  $scope.showChangePasswordLinks = function(userid) {
    return !$scope.newRecord && $scope.modelCopy[userid] != '';
  };

  $scope.resetClicked = function() {
    $scope.newRecord = false;
    $scope.cancelPasswordChange();
  };

  $scope.setNewRecord = function() {
    $scope.newRecord = true;
  };

  init();
}]);
