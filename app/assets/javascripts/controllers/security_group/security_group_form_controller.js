ManageIQ.angular.app.controller('securityGroupFormController', ['$http', '$scope', 'securityGroupFormId', 'miqService', function($http, $scope, securityGroupFormId, miqService) {
  $scope.securityGroupModel = { name: '' };
  $scope.formId = securityGroupFormId;
  $scope.afterGet = false;
  $scope.modelCopy = angular.copy( $scope.securityGroupModel );
  $scope.model = "securityGroupModel";

  ManageIQ.angular.scope = $scope;

  if (securityGroupFormId == 'new') {
    $scope.securityGroupModel.name = "";
    $scope.securityGroupModel.description = "";
    $scope.newRecord = true;
  } else {
    miqService.sparkleOn();

    $http.get('/security_group/security_group_form_fields/' + securityGroupFormId).success(function(data) {
      $scope.afterGet = true;
      $scope.securityGroupModel.name = data.name;
      $scope.securityGroupModel.description = data.description;
      $scope.securityGroupModel.cloud_tenant_name = data.cloud_tenant_name;
      $scope.modelCopy = angular.copy( $scope.securityGroupModel );
      miqService.sparkleOff();
    });
  }

  $scope.addClicked = function() {
    var url = 'create/new' + '?button=add';
    miqService.miqAjaxButton(url, $scope.securityGroupModel, { complete: false });
  };

  $scope.cancelClicked = function() {
    if (securityGroupFormId == 'new') {
      var url = '/security_group/create/new' + '?button=cancel';
    } else {
      var url = '/security_group/update/' + securityGroupFormId + '?button=cancel';
    }
    miqService.miqAjaxButton(url);
  };

  $scope.saveClicked = function() {
    var url = '/security_group/update/' + securityGroupFormId + '?button=save';
    miqService.miqAjaxButton(url, $scope.securityGroupModel, { complete: false });
  };

  $scope.resetClicked = function() {
    $scope.securityGroupModel = angular.copy( $scope.modelCopy );
    $scope.angularForm.$setPristine(true);
    miqService.miqFlash("warn", "All changes have been reset");
  };
}]);
