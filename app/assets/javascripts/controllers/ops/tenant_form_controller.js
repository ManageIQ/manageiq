ManageIQ.angularApplication.controller('tenantFormController', ['$http', '$scope', 'tenantFormId', 'tenantType', 'miqService', function($http, $scope, tenantFormId, tenantType, miqService) {
    var init = function() {

      $scope.tenantModel = {
        name: '',
        description: '',
        divisible: true
      };
      $scope.formId = tenantFormId;
      $scope.afterGet = false;
      $scope.modelCopy = angular.copy( $scope.tenantModel );

      ManageIQ.angularApplication.$scope = $scope;

      if (tenantFormId == 'new') {
        $scope.newRecord               = true;
        $scope.tenantModel.name        = '';
        $scope.tenantModel.description = '';
        $scope.tenantModel.default     = false;
        $scope.tenantModel.divisible   = tenantType;
        $scope.afterGet                = true;
        $scope.modelCopy               = angular.copy( $scope.tenantModel );
      } else {
        $scope.newRecord = false;
        miqService.sparkleOn();
        $http.get('/ops/tenant_form_fields/' + tenantFormId).success(function(data) {
          $scope.tenantModel.name        = data.name;
          $scope.tenantModel.description = data.description;
          $scope.tenantModel.default     = data.default;
          $scope.tenantModel.divisible   = data.divisible;

          $scope.afterGet = true;
          $scope.modelCopy = angular.copy( $scope.tenantModel );

          miqService.sparkleOff();
        });
      }

      $scope.$watch("tenantModel.name", function() {
        $scope.form = $scope.angularForm;
        $scope.model = "tenantModel";
      });
    };


    var tenantEditButtonClicked = function(buttonName, serializeFields) {
      miqService.sparkleOn();
      var url = '/ops/rbac_tenant_edit/' + tenantFormId + '?button=' + buttonName + '&divisible=' + tenantType;
      if (serializeFields === undefined) {
        miqService.miqAjaxButton(url);
      } else {
        miqService.miqAjaxButton(url, serializeFields);
      }
    };

    $scope.cancelClicked = function() {
      tenantEditButtonClicked('cancel');
      $scope.angularForm.$setPristine(true);
    };

    $scope.resetClicked = function() {
      $scope.tenantModel = angular.copy( $scope.modelCopy );
      $scope.angularForm.$setUntouched(true);
      $scope.angularForm.$setPristine(true);
      miqService.miqFlash("warn", "All changes have been reset");
    };

    $scope.saveClicked = function() {
      tenantEditButtonClicked('save', true);
      $scope.angularForm.$setPristine(true);
    };

    $scope.addClicked = function() {
      $scope.saveClicked();
    };

    $scope.toggleValueForWatch =   function(watchValue, initialValue) {
      if($scope[watchValue] == initialValue)
        $scope[watchValue] = "NO-OP";
      else if($scope[watchValue] == "NO-OP")
        $scope[watchValue] = initialValue;
    };

    init();
}]);
