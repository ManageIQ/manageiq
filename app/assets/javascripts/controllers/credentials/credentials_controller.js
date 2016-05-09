ManageIQ.angular.app.controller('credentialsController', ['$http', '$scope', 'miqService', function($http, $scope, miqService) {
  var init = function() {
    $scope.bChangeStoredPassword = undefined;
    $scope.bCancelPasswordChange = undefined;

    $scope.$on('resetClicked', function(e) {
      $scope.resetClicked();
    });

    $scope.$on('setNewRecord', function(event, args) {
      if(args != undefined) {
        $scope.newRecord = args.newRecord;
      }
      else {
        $scope.newRecord = true;
      }
    });

    $scope.$on('setUserId', function(event, args) {
      if(args != undefined) {
        $scope.modelCopy[args.userIdName] = args.userIdValue;
      }
    });

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

  $scope.showValidate = function(tab) {
    return !($scope.emsCommonModel.emstype == 'openstack_infra' && $scope.newRecord && tab == 'ssh_keypair')
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
