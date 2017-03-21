ManageIQ.angular.app.controller('networkRouterFormController', ['$http', '$scope', 'networkRouterFormId', 'miqService', function($http, $scope, networkRouterFormId, miqService) {
  $scope.networkRouterModel = {
    name: '',
    cloud_subnet_id: '',
  };
  $scope.formId = networkRouterFormId;
  $scope.afterGet = false;
  $scope.modelCopy = angular.copy( $scope.networkRouterModel );
  $scope.model = "networkRouterModel";

  ManageIQ.angular.scope = $scope;

  if (networkRouterFormId == 'new') {
    $scope.networkRouterModel.name = "";
    $scope.networkRouterModel.enable_snat = true;
    $scope.networkRouterModel.external_gateway = false;
    $scope.networkRouterModel.cloud_subnet_id = null;
    $scope.newRecord = true;
  } else {
    miqService.sparkleOn();

    $http.get('/network_router/network_router_form_fields/' + networkRouterFormId)
      .then(getNetworkRouterFormData)
      .catch(miqService.handleFailure);
  }

  $scope.addClicked = function() {
    var url = 'create/new' + '?button=add';
    miqService.miqAjaxButton(url, $scope.networkRouterModel, { complete: false });
  };

  $scope.cancelClicked = function() {
    if (networkRouterFormId == 'new') {
      var url = '/network_router/create/new' + '?button=cancel';
    } else {
      var url = '/network_router/update/' + networkRouterFormId + '?button=cancel';
    }
    miqService.miqAjaxButton(url, true);
  };

  $scope.saveClicked = function() {
    var url = '/network_router/update/' + networkRouterFormId + '?button=save';
    miqService.miqAjaxButton(url, $scope.networkRouterModel, { complete: false });
  };

  $scope.addInterfaceClicked = function() {
    miqService.sparkleOn();
    var url = '/network_router/add_interface/' + networkRouterFormId + '?button=add';
    miqService.miqAjaxButton(url, $scope.networkRouterModel, { complete: false });
  };

  $scope.removeInterfaceClicked = function() {
    miqService.sparkleOn();
    var url = '/network_router/remove_interface/' + networkRouterFormId + '?button=remove';
    miqService.miqAjaxButton(url, $scope.networkRouterModel, { complete: false });
  };

  $scope.resetClicked = function() {
    $scope.networkRouterModel = angular.copy( $scope.modelCopy );
    $scope.angularForm.$setPristine(true);
    miqService.miqFlash("warn", "All changes have been reset");
  };

  $scope.filterNetworkManagerChanged = function(id) {
    miqService.sparkleOn();
    $http.get('/network_router/network_router_networks_by_ems/' + id)
      .then(getNetworkRouterFormByEmsData)
      .catch(miqService.handleFailure);
  };

  $scope.filterCloudNetworkChanged = function(id) {
    miqService.sparkleOn();
    $http.get('/network_router/network_router_subnets_by_network/' + id)
      .then(getNetworkRouterFormByNetworkData)
      .catch(miqService.handleFailure);
  };

  function getNetworkRouterFormData(response) {
    var data = response.data;

    $scope.afterGet = true;
    $scope.available_networks = data.available_networks;
    $scope.available_subnets = data.available_subnets;
    $scope.networkRouterModel.name = data.name;
    $scope.networkRouterModel.cloud_network_id = data.cloud_network_id;
    $scope.networkRouterModel.cloud_subnet_id = data.cloud_subnet_id;
    $scope.networkRouterModel.ems_id = data.ems_id;
    $scope.networkRouterModel.enable_snat = data.enable_snat;
    $scope.networkRouterModel.external_gateway = data.external_gateway;

    $scope.modelCopy = angular.copy( $scope.networkRouterModel );
    miqService.sparkleOff();
  }

  function getNetworkRouterFormByEmsData(response) {
    var data = response.data;

    $scope.available_networks = data.available_networks;
    miqService.sparkleOff();
  }

  function getNetworkRouterFormByNetworkData(response) {
    var data = response.data;

    $scope.available_subnets = data.available_subnets;
    miqService.sparkleOff();
  }
}]);
