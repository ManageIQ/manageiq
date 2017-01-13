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
    $scope.networkRouterModel.cloud_subnet_id = "";
    $scope.newRecord = true;
  } else {
    miqService.sparkleOn();

    $http.get('/network_router/network_router_form_fields/' + networkRouterFormId).success(function(data) {
      $scope.afterGet = true;
      $scope.networkRouterModel.name = data.name;
      $scope.networkRouterModel.cloud_subnet_id = "";

      $scope.modelCopy = angular.copy( $scope.networkRouterModel );
      miqService.sparkleOff();
    });
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
    $http.get('/network_router/network_router_networks_by_ems/' + id).success(function(data) {
      $scope.available_networks = data.available_networks;
      miqService.sparkleOff();
    });
  };
}]);
