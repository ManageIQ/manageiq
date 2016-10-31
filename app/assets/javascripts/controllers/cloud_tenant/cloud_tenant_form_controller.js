ManageIQ.angular.app.controller('cloudTenantFormController', ['$http', '$scope', 'cloudTenantFormId', 'miqService', function($http, $scope, cloudTenantFormId, miqService) {
  $scope.cloudTenantModel = { name: '', ems_id: '' };
  $scope.formId = cloudTenantFormId;
  $scope.afterGet = false;
  $scope.modelCopy = angular.copy( $scope.cloudTenantModel );
  $scope.model = "cloudTenantModel";

  ManageIQ.angular.scope = $scope;

  if (cloudTenantFormId == 'new') {
    $scope.cloudTenantModel.name = "";
  } else {
    miqService.sparkleOn();

    $http.get('/cloud_tenant/cloud_tenant_form_fields/' + cloudTenantFormId).success(function(data) {
      $scope.afterGet = true;
      $scope.cloudTenantModel.name = data.name;

      $scope.modelCopy = angular.copy( $scope.cloudTenantModel );
      miqService.sparkleOff();
    });
  }

  $scope.cancelClicked = function() {
    if (cloudTenantFormId == 'new') {
      var url = '/cloud_tenant/create/new' + '?button=cancel';
    } else {
      var url = '/cloud_tenant/update/' + cloudTenantFormId + '?button=cancel';
    }
    miqService.miqAjaxButton(url);
  };

  $scope.saveClicked = function() {
    if (cloudTenantFormId == 'new') {
      var url = 'create/new' + '?button=add';
    } else {
    var url = '/cloud_tenant/update/' + cloudTenantFormId + '?button=save';
    }
    miqService.miqAjaxButton(url, $scope.cloudTenantModel, { complete: false });
  };

  $scope.resetClicked = function() {
    $scope.cloudTenantModel = angular.copy( $scope.modelCopy );
    $scope.angularForm.$setPristine(true);
    miqService.miqFlash("warn", "All changes have been reset");
  };
}]);
