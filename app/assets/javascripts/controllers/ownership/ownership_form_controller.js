ManageIQ.angular.app.controller('ownershipFormController', ['$http', '$scope', 'objectIds', 'miqService', function($http, $scope, objectIds, miqService) {
  var init = function() {
    $scope.ownershipModel = {
      user: '',
      group: ''
    };
    $scope.afterGet  = false;
    $scope.newRecord = false;
    $scope.modelCopy = angular.copy( $scope.ownershipModel );
    $scope.model     = "ownershipModel";
    $scope.objectIds = objectIds;
    $scope.saveable = miqService.saveable;

    ManageIQ.angular.scope = $scope;

    miqService.sparkleOn();
    $http.get('ownership_form_fields/' + objectIds.join(',')).success(function(data) {
      $scope.ownershipModel.user = data.user;
      $scope.ownershipModel.group = data.group;
      $scope.afterGet = true;
      $scope.modelCopy = angular.copy( $scope.ownershipModel );
      miqService.sparkleOff();
    });
  };

  $scope.canValidateBasicInfo = function () {
    return $scope.isBasicInfoValid();
  };

  $scope.isBasicInfoValid = function() {
    return ( $scope.angularForm.user && $scope.angularForm.user.$valid) &&
      ($scope.angularForm.group && $scope.angularForm.group.$valid);
  };


  var ownershipEditButtonClicked = function(buttonName, data) {
    var url = 'ownership_update/' + '?button=' + buttonName;
    miqService.miqAjaxButton(url, data);
  };

  $scope.cancelClicked = function() {
    ownershipEditButtonClicked('cancel');
  };

  $scope.resetClicked = function() {
    $scope.ownershipModel = angular.copy( $scope.modelCopy );
    $scope.angularForm.$setPristine(true);
    miqService.miqFlash("warn", __("All changes have been reset"));
  };

  $scope.saveClicked = function() {
    ownershipEditButtonClicked('save', {
      objectIds: $scope.objectIds,
      user: $scope.ownershipModel.user,
      group: $scope.ownershipModel.group,
    });
  };

  $scope.addClicked = $scope.saveClicked;

  init();
}]);
