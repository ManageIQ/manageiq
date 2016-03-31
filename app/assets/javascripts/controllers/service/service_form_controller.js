ManageIQ.angular.app.controller('serviceFormController', ['$http', '$scope', '$window', '$timeout', 'serviceFormId', 'miqService', 'serviceData', function($http, $scope, $window, $timeout, serviceFormId, miqService, serviceData) {
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
      return API.post('/api/services/' + serviceFormId,
                      angular.toJson({action:   "edit",
                                      resource: {name:        $scope.serviceModel.name,
                                                 description: $scope.serviceModel.description
                                                }
                                     })).then(handleSuccess, handleFailure);

      function handleSuccess(response) {
        var msg = sprintf(__("Service %s was saved"), $scope.serviceModel.name);
        $timeout(function () {
          $window.location.href = '/service/explorer?flash_msg=' + msg;
          miqService.sparkleOff();
          miqService.miqFlash("success", msg);
        });
      }

      function handleFailure(response) {
        var msg = sprintf(__("Error during 'Service Edit': [%s - %s]"), response.status, response.responseText);
        $timeout(function () {
          $window.location.href = '/service/explorer?flash_msg=' + msg + '&flash_error=true';
          miqService.sparkleOff();
          miqService.miqFlash("error", msg);
        });
      }
    };

    $scope.cancelClicked = function() {
      var msg = sprintf(__("Edit of Service %s was cancelled by the user"), $scope.serviceModel.description);
      $timeout(function () {
        $window.location.href = '/service/explorer?flash_msg=' + msg;
        miqService.sparkleOff();
        miqService.miqFlash("success", msg);
      });
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
