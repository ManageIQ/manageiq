ManageIQ.angular.app.controller('serviceFormController', ['$http', '$scope', 'serviceFormId', 'miqService', function($http, $scope, serviceFormId, miqService) {
    var init = function() {

      $scope.serviceModel = {
        name: '',
        description: ''
      };
      $scope.formId    = serviceFormId;
      $scope.afterGet  = false;
      $scope.newRecord = false;
      $scope.modelCopy = angular.copy( $scope.serviceModel );
      $scope.model     = "serviceModel";
      ManageIQ.angular.scope = $scope;

      miqService.sparkleOn();
      $http.get('/service/service_form_fields/' + serviceFormId).success(function(data) {
        $scope.serviceModel.name        = data.name;
        $scope.serviceModel.description = data.description;

        $scope.afterGet = true;
        $scope.modelCopy = angular.copy( $scope.serviceModel );
        miqService.sparkleOff();
      });
    };

    var serviceEditButtonClicked = function(buttonName, serializeFields) {
      miqService.sparkleOn();
      var url = '/service/service_edit/' + serviceFormId + '?button=' + buttonName;
      
      miqService.miqAjaxButton(url, serializeFields);
    };

    $scope.cancelClicked = function() {
      serviceEditButtonClicked('cancel');
      $scope.angularForm.$setPristine(true);
    };

    $scope.resetClicked = function() {
      $scope.serviceModel = angular.copy( $scope.modelCopy );
      $scope.angularForm.$setUntouched(true);
      $scope.angularForm.$setPristine(true);
      miqService.miqFlash("warn", __("All changes have been reset"));
    };

    $scope.saveClicked = function() {
      serviceEditButtonClicked('save', true);
      $scope.angularForm.$setPristine(true);
    };

    init();
}]);
