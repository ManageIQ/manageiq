ManageIQ.angular.app.controller('cloudNetworkFormController', ['$http', '$scope', 'cloudNetworkFormId', 'miqService', function($http, $scope, cloudNetworkFormId, miqService) {
  $scope.cloudNetworkModel = { name: '', ems_id: '', cloud_tenant_id: '', provider_network_type: ''  };
  $scope.formId = cloudNetworkFormId;
  $scope.afterGet = false;
  $scope.modelCopy = angular.copy( $scope.cloudNetworkModel );
  $scope.model = "cloudNetworkModel";

  ManageIQ.angular.scope = $scope;

  if (cloudNetworkFormId == 'new') {
    $scope.cloudNetworkModel.name = "";
    $scope.newRecord = true;
    $scope.cloudNetworkModel.enabled = true;
    $scope.cloudNetworkModel.external_facing = false;
    $scope.cloudNetworkModel.shared = false;
    $scope.cloudNetworkModel.vlan_transparent = false;
  } else {
    miqService.sparkleOn();

    $http.get('/cloud_network/cloud_network_form_fields/' + cloudNetworkFormId).success(function(data) {
      $scope.afterGet = true;
      $scope.cloudNetworkModel.name = data.name;
      $scope.cloudNetworkModel.cloud_tenant_name = data.cloud_tenant_name;
      $scope.cloudNetworkModel.enabled = data.enabled;
      $scope.cloudNetworkModel.external_facing = data.external_facing;
      $scope.cloudNetworkModel.port_security_enabled = data.port_security_enabled;
      $scope.cloudNetworkModel.provider_network_type = data.provider_network_type;
      $scope.cloudNetworkModel.qos_policy_id = data.qos_policy_id;
      $scope.cloudNetworkModel.shared = data.shared;
      $scope.cloudNetworkModel.vlan_transparent = data.vlan_transparent;
      $scope.modelCopy = angular.copy( $scope.cloudNetworkModel );
      miqService.sparkleOff();
    });
  }

  $scope.addClicked = function() {
    var url = 'create/new' + '?button=add';
    miqService.miqAjaxButton(url, $scope.cloudNetworkModel, { complete: false });
  };

  $scope.cancelClicked = function() {
    if (cloudNetworkFormId == 'new') {
      var url = '/cloud_network/create/new' + '?button=cancel';
    } else {
      var url = '/cloud_network/update/' + cloudNetworkFormId + '?button=cancel';
    }
    miqService.miqAjaxButton(url);
  };

  $scope.saveClicked = function() {
    var url = '/cloud_network/update/' + cloudNetworkFormId + '?button=save';
    miqService.miqAjaxButton(url, $scope.cloudNetworkModel, { complete: false });
  };

  $scope.resetClicked = function() {
    $scope.cloudNetworkModel = angular.copy( $scope.modelCopy );
    $scope.angularForm.$setPristine(true);
    miqService.miqFlash("warn", "All changes have been reset");
  };
}]);
