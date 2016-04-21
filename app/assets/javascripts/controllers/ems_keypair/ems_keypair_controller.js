ManageIQ.angular.app.controller('emsKeypairController', ['$http', '$scope', 'miqService', function($http, $scope, miqService) {
  var init = function() {
    $scope.bChangeStoredPrivateKey = undefined;
    $scope.bCancelPrivateKeyChange = undefined;

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
      $scope.bChangeStoredPrivateKey = false;
      $scope.bCancelPrivateKeyChange = false;
    }
  };

  $scope.changeStoredPrivateKey = function() {
    $scope.bChangeStoredPrivateKey = true;
    $scope.bCancelPrivateKeyChange = false;
    $scope.emsCommonModel.ssh_keypair_password = '';
  };

  $scope.cancelPrivateKeyChange = function() {
    if($scope.bChangeStoredPrivateKey) {
      $scope.bCancelPrivateKeyChange = true;
      $scope.bChangeStoredPrivateKey = false;
      $scope.emsCommonModel.ssh_keypair_password = '';
    }
  };

  $scope.showVerifyPrivateKey = function(userid) {
    return $scope.newRecord || (!$scope.showChangePrivateKeyLinks(userid)) || $scope.bChangeStoredPrivateKey;
  };

  $scope.showChangePrivateKeyLinks = function(userid) {
    return !$scope.newRecord && $scope.modelCopy[userid] != '';
  };

  $scope.resetClicked = function() {
    $scope.newRecord = false;
    $scope.cancelPrivateKeyChange();
  };

  init();
}]);
