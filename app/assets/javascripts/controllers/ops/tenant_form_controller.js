ManageIQ.angular.app.controller('tenantFormController', ['$http', '$scope', 'tenantFormId', 'tenantType', 'miqService', function($http, $scope, tenantFormId, tenantType, miqService) {
    var init = function() {

      $scope.tenantModel = {
        name: '',
        description: '',
        divisible: true,
        use_config_for_attributes: false
      };
      $scope.formId = tenantFormId;
      $scope.afterGet = false;
      $scope.modelCopy = angular.copy( $scope.tenantModel );
      $scope.model = "tenantModel";

      ManageIQ.angular.scope = $scope;

      if (tenantFormId == 'new') {
        $scope.newRecord                             = true;
        $scope.tenantModel.name                      = '';
        $scope.tenantModel.description               = '';
        $scope.tenantModel.default                   = false;
        $scope.tenantModel.divisible                 = tenantType;
        $scope.tenantModel.use_config_for_attributes = false;

        $scope.afterGet  = true;
        $scope.modelCopy = angular.copy( $scope.tenantModel );
      } else {
        $scope.newRecord = false;
        miqService.sparkleOn();
        $http.get('/ops/tenant_form_fields/' + tenantFormId).success(function(data) {
          $scope.tenantModel.name                      = data.name;
          $scope.tenantModel.description               = data.description;
          $scope.tenantModel.default                   = data.default;
          $scope.tenantModel.divisible                 = data.divisible;
          $scope.tenantModel.use_config_for_attributes = data.use_config_for_attributes;

          $scope.afterGet = true;
          $scope.modelCopy = angular.copy( $scope.tenantModel );

          miqService.sparkleOff();
        });
      }
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
      miqService.miqFlash("warn", __("All changes have been reset"));
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
