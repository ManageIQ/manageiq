ManageIQ.angular.app.controller('credentialsController', ['$scope', function($scope) {
  var init = function() {
    $scope.bChangeStoredPassword = undefined;
    $scope.bCancelPasswordChange = undefined;

    $scope.$on('resetClicked', function(_e) {
      $scope.resetClicked();
    });

    $scope.$on('setNewRecord', function(_event, args) {
      $scope.newRecord = args ? args.newRecord : true;
    });

    $scope.$on('setUserId', function(_event, args) {
      if (args) {
        $scope.modelCopy[args.userIdName] = args.userIdValue;
      }
    });

    if ($scope.formId == 'new') {
      $scope.newRecord = true;
    } else {
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
    if ($scope.bChangeStoredPassword) {
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

  init();
}]);
