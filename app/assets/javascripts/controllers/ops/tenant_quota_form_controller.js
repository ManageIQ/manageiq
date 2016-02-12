ManageIQ.angular.app.controller('tenantQuotaFormController',['$http', '$scope', 'tenantQuotaFormId', 'tenantType', 'miqService', function($http, $scope, tenantQuotaFormId, tenantType, miqService) {
  var init = function() {
    $scope.tenantQuotaModel = {
      name:'',
      quotas:{}
    };
    $scope.formId = tenantQuotaFormId;
    $scope.afterGet = false;
    $scope.modelCopy = angular.copy( $scope.tenantQuotaModel );
    $scope.model = "tenantQuotaModel";

    ManageIQ.angular.scope = $scope;
    $scope.newRecord = false;
    miqService.sparkleOn();
    $http.get('/ops/tenant_quotas_form_fields/' + tenantQuotaFormId).success(function(data) {
      $scope.tenantQuotaModel.name = data.name;
      $scope.tenantQuotaModel.quotas = angular.copy(data.quotas);
      var GIGABYTE = 1024 * 1024 * 1024;
      for (var key in $scope.tenantQuotaModel.quotas ){
        if($scope.tenantQuotaModel.quotas.hasOwnProperty(key)) {
          var quota =  $scope.tenantQuotaModel.quotas[key];
          if(quota['value']){
            if ( quota['unit'] === "bytes")
              quota['value'] = quota['value'] / GIGABYTE;
            quota['enforced'] = true;
          }
          else
            quota['enforced'] = false;
          if(quota['format'] === "general_number_precision_0")
            quota['valpattern'] = "^[1-9][0-9]*$";
          else
            quota['valpattern'] =/^\s*(?=.*[1-9])\d*(?:\.\d{1,6})?\s*$/;
        }
      }
      $scope.afterGet = true;
      $scope.modelCopy = angular.copy( $scope.tenantQuotaModel );
      miqService.sparkleOff();
    });
  };

  var tenantManageQuotasButtonClicked = function(buttonName, serializeFields) {
    miqService.sparkleOn();
    var url = '/ops/rbac_tenant_manage_quotas/' + tenantQuotaFormId + '?button=' + buttonName + '&divisible=' + tenantType;

    miqService.miqAjaxButton(url, serializeFields);
  };

  $scope.cancelClicked = function() {
    tenantManageQuotasButtonClicked('cancel');
    $scope.angularForm.$setPristine(true);
  };

  $scope.resetClicked = function() {
    $scope.tenantQuotaModel = angular.copy( $scope.modelCopy );
    $scope.angularForm.$setUntouched(true);
    $scope.angularForm.$setPristine(true);
    miqService.miqFlash("warn", __("All changes have been reset"));
  };

  $scope.saveClicked = function() {
    var data = {};
    var GIGABYTE = 1024 * 1024 * 1024;
    for(var key in $scope.tenantQuotaModel.quotas){
      if($scope.tenantQuotaModel.quotas.hasOwnProperty(key)) {
        var quota =  $scope.tenantQuotaModel.quotas[key];
        if( quota['value'] ){
        q = {};
        if(quota['unit'] === "bytes")
          q['value'] = quota['value'] * GIGABYTE;
        else
          q['value'] = quota['value'];
          data[key] = q;
        }
      }
    }
    tenantManageQuotasButtonClicked('save', { 'quotas' : data});
    $scope.angularForm.$setPristine(true);
  };

  $scope.check_quotas_changed = function() {
    for (var key in $scope.tenantQuotaModel.quotas) {
      if($scope.tenantQuotaModel.quotas.hasOwnProperty(key)){
        if($scope.tenantQuotaModel.quotas[key]['value'] != $scope.modelCopy.quotas[key]['value'])
          return true;
      }
    }
    return false;
  };

  $scope.enforcedChanged = function(name) {
    miqService.miqFlashClear();
    for ( var key in $scope.tenantQuotaModel.quotas ) {
      if ($scope.tenantQuotaModel.quotas.hasOwnProperty(key) && (key == name)) {
        if (!$scope.tenantQuotaModel.quotas[key]['enforced'])
          $scope.tenantQuotaModel.quotas[key]['value'] = null;
        else
          if($scope.modelCopy.quotas[key]['value'])
            $scope.tenantQuotaModel.quotas[key]['value'] = $scope.modelCopy.quotas[key]['value'];
          else
            $scope.tenantQuotaModel.quotas[key]['value'] = 0;
        if (!$scope.check_quotas_changed())
          $scope.angularForm.$setPristine(true);
      }
    }
  };

  $scope.valueChanged = function() {
    miqService.miqFlashClear();
    if (!$scope.check_quotas_changed())
      $scope.angularForm.$setPristine(true);
  };

  init();
}]);
