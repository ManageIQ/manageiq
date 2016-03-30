ManageIQ.angular.app.controller('serviceFormController', ['$http', '$scope', 'serviceFormId', 'miqService',  'serviceData', function($http, $scope, serviceFormId, miqService, serviceData) {
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

      // need this in order to get Abandon Changes? prompt when leaving form without saving
      $scope.$watch("serviceModel.name", function() {
        $scope.form  = $scope.angularForm;
     });
    };

    var serviceEditButtonClicked = function(buttonName, serializeFields) {
      miqService.sparkleOn();
      var url = '/service/edit/' + serviceFormId + '?button=' + buttonName;
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
