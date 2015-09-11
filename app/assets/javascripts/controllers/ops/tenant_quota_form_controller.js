ManageIQ.angularApplication.controller('tenantQuotaFormController',['$http', '$scope', 'tenantQuotaFormId', 'tenantType', 'miqService', function($http, $scope, tenantQuotaFormId, tenantType, miqService) {
    var init = function() {
        $scope.tenantQuotaModel = {
            name:'',
            quotas:{}
        };
        $scope.formId = tenantQuotaFormId;
        $scope.afterGet = false;
        $scope.modelCopy = angular.copy( $scope.tenantQuotaModel );
        $scope.saveable = miqService.saveable;

        ManageIQ.angularApplication.$scope = $scope;

        miqService.sparkleOn();
        $http.get('/ops/tenant_quotas_form_fields/' + tenantQuotaFormId).success(function(data) {
            $scope.tenantQuotaModel.name = data.name;
            $scope.tenantQuotaModel.quotas = angular.copy(data.quotas);
            const GIGABYTE = 1024 * 1024 * 1024;
            for ( var key in $scope.tenantQuotaModel.quotas ){
                if($scope.tenantQuotaModel.quotas.hasOwnProperty(key)) {
                    var quota =  $scope.tenantQuotaModel.quotas[key];
                    if( quota['value'] ){
                        if ( quota['unit'] === "bytes")
                            quota['value'] = quota['value'] / GIGABYTE;
                        quota['enforced'] = true;
                    }
                    else
                        quota['enforced'] = false;
                    if(quota['format'] === "general_number_precision_0")
                        quota['valpattern'] = "^[0-9]*$";
                    else
                        quota['valpattern'] = "^[+]?([0-9]+(\.[0-9]*)?|\.[0-9]+)$";
                }
            }
            $scope.afterGet = true;
            $scope.modelCopy = angular.copy( $scope.tenantQuotaModel );
            miqService.sparkleOff();
        });
        $scope.$watch("tenantQuotaModel.name", function() {
            $scope.form = $scope.angularForm;
            $scope.model = "tenantQuotaModel";
        });
    };
    var tenantManageQuotasButtonClicked = function(buttonName, serializeFields) {
        miqService.sparkleOn();
        var url = '/ops/rbac_tenant_manage_quotas/' + tenantQuotaFormId + '?button=' + buttonName + '&divisible=' + tenantType;
        if (serializeFields === undefined) {
            miqService.miqAjaxButton(url);
        } else {
            miqService.miqAjaxButton(url, serializeFields);
        }
    };
    $scope.cancelClicked = function() {
        tenantManageQuotasButtonClicked('cancel');
        $scope.angularForm.$setPristine(true);
    };
    $scope.resetClicked = function() {
        $scope.tenantQuotaModel = angular.copy( $scope.modelCopy );
        $scope.angularForm.$setUntouched(true);
        $scope.angularForm.$setPristine(true);
        miqService.miqFlash("warn", "All changes have been reset");
    };
    $scope.saveClicked = function() {
        var data = {};
        const GIGABYTE = 1024 * 1024 * 1024;
        for ( var key in $scope.tenantQuotaModel.quotas ){
            if($scope.tenantQuotaModel.quotas.hasOwnProperty(key)) {
                var quota =  $scope.tenantQuotaModel.quotas[key];
                 if( quota['value'] ){
                     q = {};
                     if ( quota['unit'] === "bytes")
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
    $scope.toggleValueForWatch =   function(watchValue, initialValue) {
        if($scope[watchValue] == initialValue)
            $scope[watchValue] = "NO-OP";
        else if($scope[watchValue] == "NO-OP")
            $scope[watchValue] = initialValue;
    };
    $scope.enforced_changed = function(name) {
        for ( var key in $scope.tenantQuotaModel.quotas ) {
            if ($scope.tenantQuotaModel.quotas.hasOwnProperty(key) && (key == name)) {
                if (!$scope.tenantQuotaModel.quotas[key]['enforced']) {
                    $scope.tenantQuotaModel.quotas[key]['value'] = null;
                    $scope.form.$dirty = true;
                }
            }
        }
    };
    init();
}]);
