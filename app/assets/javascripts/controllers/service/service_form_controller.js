ManageIQ.angular.app.controller('serviceFormController', ['$http', '$scope', 'serviceFormId', 'miqService', 'postService', 'serviceData', function($http, $scope, serviceFormId, miqService, postService, serviceData) {
    var init = function() {
      $scope.serviceModel = {
        name: '',
        description: ''
      };
      $scope.formId    = serviceFormId;
      $scope.afterGet  = false;
      $scope.newRecord = false;
      $scope.model     = "serviceModel";
      ManageIQ.angular.scope = $scope;

      $scope.serviceModel.name = serviceData.name;
      $scope.serviceModel.description = serviceData.description;
      $scope.modelCopy = angular.copy( $scope.serviceModel );
    };

    $scope.cancelClicked = function() {
      var msg = sprintf(__("Edit of Service %s was cancelled by the user"), $scope.serviceModel.description);
      postService.cancelOperation('/service/explorer', msg);
      $scope.angularForm.$setPristine(true);
    };

    $scope.resetClicked = function() {
      $scope.serviceModel = angular.copy( $scope.modelCopy );
      $scope.angularForm.$setUntouched(true);
      $scope.angularForm.$setPristine(true);
      miqService.miqFlash("warn", __("All changes have been reset"));
    };

    $scope.saveClicked = function() {
      var successMsg = sprintf(__("Service %s was saved"), $scope.serviceModel.name);
      postService.saveRecord('/api/services/' + serviceFormId,
        '/service/explorer',
        {name:         $scope.serviceModel.name,
          description: $scope.serviceModel.description},
        successMsg);
      $scope.angularForm.$setPristine(true);
    };

    init();
}]);
