ManageIQ.angular.app.controller('floatingIpFormController', ['$http', '$scope', 'floatingIpFormId', 'miqService', function($http, $scope, floatingIpFormId, miqService) {
  $scope.floatingIpModel = { name: '' };
  $scope.formId = floatingIpFormId;
  $scope.afterGet = false;
  $scope.modelCopy = angular.copy( $scope.floatingIpModel );
  $scope.model = "floatingIpModel";

  ManageIQ.angular.scope = $scope;

  if (floatingIpFormId == 'new') {
    $scope.floatingIpModel.name = "";
    $scope.floatingIpModel.description = "";
    $scope.newRecord = true;
  } else {
    miqService.sparkleOn();

    $http.get('/floating_ip/floating_ip_form_fields/' + floatingIpFormId).success(function(data) {
      $scope.afterGet = true;
      $scope.floatingIpModel.network_port_ems_ref = data.network_port_ems_ref;
      $scope.modelCopy = angular.copy( $scope.floatingIpModel );
      miqService.sparkleOff();
    });
  }

  $scope.addClicked = function() {
    var url = 'create/new' + '?button=add';
    miqService.miqAjaxButton(url, $scope.floatingIpModel, { complete: false });
  };

  $scope.cancelClicked = function() {
    if (floatingIpFormId == 'new') {
      var url = '/floating_ip/create/new' + '?button=cancel';
    } else {
      var url = '/floating_ip/update/' + floatingIpFormId + '?button=cancel';
    }
    miqService.miqAjaxButton(url);
  };

  $scope.saveClicked = function() {
    var url = '/floating_ip/update/' + floatingIpFormId + '?button=save';
    miqService.miqAjaxButton(url, $scope.floatingIpModel, { complete: false });
  };

  $scope.resetClicked = function() {
    $scope.floatingIpModel = angular.copy( $scope.modelCopy );
    $scope.angularForm.$setPristine(true);
    miqService.miqFlash("warn", "All changes have been reset");
  };

  $scope.filterNetworkManagerChanged = function(id) {
    miqService.sparkleOn();
    $http.get('/floating_ip/networks_by_ems/' + id).success(function(data) {
      $scope.available_networks = data.available_networks;
      miqService.sparkleOff();
    });
  };
}]);
