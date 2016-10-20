ManageIQ.angular.app.controller('hostAggregateFormController', ['$http', '$scope', 'hostAggregateFormId', 'miqService', function($http, $scope, hostAggregateFormId, miqService) {
  $scope.hostAggregateModel = {
    name: '',
    ems_id: '',
    availability_zone: '',
    metadata: '',
    host_id: '',
  };
  $scope.formId = hostAggregateFormId;
  $scope.afterGet = false;
  $scope.modelCopy = angular.copy( $scope.hostAggregateModel );
  $scope.model = "hostAggregateModel";

  ManageIQ.angular.scope = $scope;

  if (hostAggregateFormId == 'new') {
    $scope.hostAggregateModel.name = "";
    $scope.hostAggregateModel.ems_id = "";
    $scope.hostAggregateModel.availability_zone = "";
    $scope.hostAggregateModel.metadata = "";
    $scope.hostAggregateModel.host_id = "";
  } else {
    miqService.sparkleOn();

    $http.get('/host_aggregate/host_aggregate_form_fields/' + hostAggregateFormId).success(function(data) {
      $scope.afterGet = true;
      $scope.hostAggregateModel.name = data.name;
      $scope.hostAggregateModel.ems_id = data.ems_id;
      $scope.hostAggregateModel.host_id = "";

      $scope.modelCopy = angular.copy( $scope.hostAggregateModel );
      miqService.sparkleOff();
    });
  }

  $scope.addClicked = function() {
    miqService.sparkleOn();
    var url = 'create/new' + '?button=add';
    miqService.miqAjaxButton(url, $scope.hostAggregateModel, { complete: false });
  };

  $scope.cancelClicked = function() {
    miqService.sparkleOn();
    if (hostAggregateFormId == 'new') {
      var url = '/host_aggregate/create/new' + '?button=cancel';
    } else {
      var url = '/host_aggregate/update/' + hostAggregateFormId + '?button=cancel';
    }
    miqService.miqAjaxButton(url);
  };

  $scope.saveClicked = function() {
    miqService.sparkleOn();
    var url = '/host_aggregate/update/' + hostAggregateFormId + '?button=save';
    miqService.miqAjaxButton(url, $scope.hostAggregateModel, { complete: false });
  };

  $scope.addHostClicked = function() {
    miqService.sparkleOn();
    var url = '/host_aggregate/add_host/' + hostAggregateFormId + '?button=addHost';
    miqService.miqAjaxButton(url, $scope.hostAggregateModel, { complete: false });
  };

  $scope.removeHostClicked = function() {
    miqService.sparkleOn();
    var url = '/host_aggregate/remove_host/' + hostAggregateFormId + '?button=removeHost';
    miqService.miqAjaxButton(url, $scope.hostAggregateModel, { complete: false });
  };

  $scope.cancelAddHostClicked = function() {
    miqService.sparkleOn();
    var url = '/host_aggregate/add_host/' + hostAggregateFormId + '?button=cancel';
    miqService.miqAjaxButton(url);
  };

  $scope.cancelRemoveHostClicked = function() {
    miqService.sparkleOn();
    var url = '/host_aggregate/remove_host/' + hostAggregateFormId + '?button=cancel';
    miqService.miqAjaxButton(url);
  };

  $scope.resetClicked = function() {
    $scope.hostAggregateModel = angular.copy( $scope.modelCopy );
    $scope.angularForm.$setPristine(true);
    miqService.miqFlash("warn", "All changes have been reset");
  };
}]);
