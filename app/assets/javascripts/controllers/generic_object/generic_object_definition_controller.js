ManageIQ.angular.app.controller('genericObjectDefinitionFormController', ['$http', '$scope', 'miqService', 'genericObjectSubscriptionService', function($http, $scope, miqService, genericObjectSubscriptionService) {
  var init = function() {
    hideAndClearForm();

    $scope.newRecord = true;
    $scope.showSingleItem = false;

    genericObjectSubscriptionService.subscribeToShowAddForm(showAddForm);
    genericObjectSubscriptionService.subscribeToShowEditForm(showEditForm);
    genericObjectSubscriptionService.subscribeToTreeClicks(showSelectedItem);
    genericObjectSubscriptionService.subscribeToRootTreeclicks(showAllItems);
  };

  var showAddForm = function(_response) {
    $scope.clearForm();
    $scope.newRecord = true;
    $scope.showForm = true;
    sendDataWithRx({eventType: 'deselectTreeNodes'});
  };

  var showEditForm = function(_response) {
    $scope.backupGenericObjectDefinitionModel = angular.copy($scope.genericObjectDefinitionModel);
    $scope.newRecord = false;
    $scope.showForm = true;
    sendDataWithRx({eventType: 'updateToolbarCount', countSelected: 0});
  };

  var showAllItems = function(response) {
    $scope.genericObjectList = response;
    $scope.showSingleItem = false;
    $scope.showForm = false;
    sendDataWithRx({eventType: 'updateToolbarCount', countSelected: 0});
  };

  var addedOrUpdatedGenericObject = function(_data) {
    var successCallback = function(response) {
      sendDataWithRx({eventType: 'treeUpdated', response: JSON.parse(response.data.tree_data)});
    };

    $http.get('tree_data').then(successCallback);
  };

  var hideAndClearForm = function() {
    $scope.clearForm();
    $scope.showForm = false;
  };

  var showSelectedItem = function(response) {
    $scope.genericObjectDefinitionModel.id = response.id;
    $scope.genericObjectDefinitionModel.name = response.name;
    $scope.genericObjectDefinitionModel.description = response.description;
    $scope.showForm = false;
    $scope.showSingleItem = true;
    sendDataWithRx({eventType: 'updateToolbarCount', countSelected: 1});
    miqService.sparkleOff();
  };

  $scope.clearForm = function() {
    $scope.genericObjectDefinitionModel = {
      id: '',
      name: '',
      description: ''
    };
  };

  $scope.listObjectClicked = function(name) {
    sendDataWithRx({eventType: 'singleItemSelected', response: name});
    sendDataWithRx({eventType: 'updateToolbarCount', countSelected: 1});
  };

  $scope.addClicked = function() {
    var data = $scope.genericObjectDefinitionModel;

    $http.post('create', data).then(addedOrUpdatedGenericObject);
  };

  $scope.saveClicked = function() {
    var data = $scope.genericObjectDefinitionModel;

    $http.post('save', data).then(addedOrUpdatedGenericObject);
  };

  $scope.cancelClicked = function() {
    hideAndClearForm();
    sendDataWithRx({eventType: 'cancelClicked'});
    sendDataWithRx({eventType: 'updateToolbarCount', countSelected: 0});
    $scope.angularForm.$setPristine(true);
  };

  $scope.resetClicked = function() {
    $scope.genericObjectDefinitionModel = angular.copy($scope.backupGenericObjectDefinitionModel);
    $scope.angularForm.$setPristine(true);
  };

  init();
}]);
