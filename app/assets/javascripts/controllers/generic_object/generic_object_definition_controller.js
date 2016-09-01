ManageIQ.angular.app.controller('genericObjectDefinitionFormController', ['$http', '$scope', 'miqService', 'genericObjectSubscriptionService', function($http, $scope, miqService, genericObjectSubscriptionService) {
  var init = function() {
    hideAndClearForm();

    $scope.newRecord = true;
    $scope.showSingleItem = false;

    genericObjectSubscriptionService.subscribeToShowAddForm(showAddForm);
    genericObjectSubscriptionService.subscribeToTreeClicks(showSelectedItem);
    genericObjectSubscriptionService.subscribeToRootTreeclicks(showAllItems);
  };

  var showAddForm = function(_response) {
    $scope.clearForm();
    $scope.showAddForm = true;
    $scope.$apply();
    sendDataWithRx({eventType: 'deselectTreeNodes'});
  };

  var showAllItems = function(response) {
    $scope.genericObjectList = response;
    $scope.showSingleItem = false;
    $scope.$apply();
  };

  var addedGenericObject = function(data) {
    var successCallback = function(response) {
      sendDataWithRx({eventType: 'treeUpdated', response: JSON.parse(response.data.tree_data)});
    };

    $http.get('tree_data').then(successCallback);
  };

  var hideAndClearForm = function() {
    $scope.clearForm();
    $scope.showAddForm = false;
  };

  var showSelectedItem = function(response) {
    var modelData = response;
    $scope.genericObjectDefinitionModel.name = modelData.name;
    $scope.genericObjectDefinitionModel.description = modelData.description;
    $scope.showAddForm = false;
    $scope.showSingleItem = true;
    miqService.sparkleOff();
    $scope.$apply();
  };

  $scope.clearForm = function() {
    $scope.genericObjectDefinitionModel = {
      name: '',
      description: ''
    };
  };

  $scope.listObjectClicked = function(name) {
    sendDataWithRx({eventType: 'singleItemSelected', response: name});
  };

  $scope.addClicked = function() {
    var data = $scope.genericObjectDefinitionModel;

    miqService.jqueryRequest('create', {
      data: data,
      dataType: 'json',
      beforeSend: true,
      complete: true,
      done: addedGenericObject
    });
  };

  $scope.cancelClicked = function() {
    hideAndClearForm();
    sendDataWithRx({eventType: 'cancelClicked'});
    $scope.angularForm.$setPristine(true);
  };

  init();
}]);
