ManageIQ.angularApplication.controller('emsCommonFormController', ['$http', '$scope', '$attrs', 'emsCommonFormId', 'miqService', function($http, $scope, $attrs, emsCommonFormId, miqService) {
  var init = function() {
    $scope.emsCommonModel = {
      name: '',
      emstype: '',
      openstack_infra_providers_exist: false,
      provider_id: '',
      zone: '',
      hostname: '',
      api_port: '',
      provider_region: '',
      default_userid: '',
      default_password: '',
      default_verify: '',
      amqp_userid: '',
      amqp_password: '',
      amqp_verify: '',
      metrics_userid: '',
      metrics_password: '',
      metrics_verify: '',
      host_default_vnc_port_start: '',
      host_default_vnc_port_end: '',
      emstype_vm: false,
      ems_common: true,
      tenant_id: ''
    };
    $scope.formId = emsCommonFormId;
    $scope.afterGet = false;
    $scope.saveable = miqService.saveable;
    $scope.validateClicked = miqService.validateClicked;
    $scope.modelCopy = angular.copy( $scope.emsCommonModel );
    $scope.formFieldsUrl = $attrs.formFieldsUrl;
    $scope.createUrl = $attrs.createUrl;
    $scope.updateUrl = $attrs.updateUrl;
    $scope.model = 'emsCommonModel';

    ManageIQ.angularApplication.$scope = $scope;

    if (emsCommonFormId == 'new') {
      $scope.newRecord                  = true;

      miqService.sparkleOn();
      $http.get($scope.formFieldsUrl + emsCommonFormId).success(function(data) {
        $scope.emsCommonModel.zone                            = data.zone;
        $scope.emsCommonModel.emstype_vm                      = data.emstype_vm;
        $scope.emsCommonModel.openstack_infra_providers_exist = data.openstack_infra_providers_exist;
        $scope.emsCommonModel.api_port                        = 5000;
        miqService.sparkleOff();
      });
      $scope.afterGet  = true;
      $scope.modelCopy = angular.copy( $scope.emsCommonModel );
    }
    else {
      $scope.newRecord = false;
      miqService.sparkleOn();

      $http.get('/ems_cloud/ems_cloud_form_fields/' + emsCommonFormId).success(function(data) {
        $scope.emsCommonModel.name                            = data.name;
        $scope.emsCommonModel.emstype                         = data.emstype;
        $scope.emsCommonModel.zone                            = data.zone;
        $scope.emsCommonModel.hostname                        = data.hostname;

        $scope.emsCommonModel.openstack_infra_providers_exist = data.openstack_infra_providers_exist;
        $scope.emsCommonModel.provider_id                     = data.provider_id.toString();

        $scope.emsCommonModel.api_port                        = data.api_port;
        $scope.emsCommonModel.provider_region                 = data.provider_region;

        $scope.emsCommonModel.default_userid                  = data.default_userid;
        $scope.emsCommonModel.default_password                = data.default_password;
        $scope.emsCommonModel.default_verify                  = data.default_verify;

        $scope.emsCommonModel.amqp_userid                     = data.amqp_userid;
        $scope.emsCommonModel.ampq_password                   = data.ampq_password;
        $scope.emsCommonModel.amqp_verify                     = data.amqp_verify;

        $scope.emsCommonModel.tenant_id                       = data.tenant_id;

        $scope.afterGet  = true;
        $scope.modelCopy = angular.copy( $scope.emsCommonModel );

        miqService.sparkleOff();
      });
    }

    if($scope.emstype == "azure")
      $scope.currentTab = "azure_default"
    else
      $scope.currentTab = "default"

    $scope.$watch("emsCommonModel.name", function() {
      $scope.form = $scope.angularForm;
      $scope.model = "emsCommonModel";
    });
  };

  $scope.changeAuthTab = function(id) {
    $scope.currentTab = id;
  }

  $scope.canValidateBasicInfo = function () {
    if ($scope.isBasicInfoValid())
      return true;
    else
      return false;
  }

  $scope.isBasicInfoValid = function() {
    if(($scope.currentTab == "default" && $scope.emsCommonModel.emstype != "azure") &&
      ($scope.emsCommonModel.emstype == "ec2" || ($scope.emsCommonModel.emstype == "openstack" && $scope.emsCommonModel.hostname)) &&
      ($scope.emsCommonModel.default_userid != '' && $scope.angularForm.default_userid.$valid &&
       $scope.emsCommonModel.default_password != '' && $scope.angularForm.default_password.$valid &&
       $scope.emsCommonModel.default_verify != '' && $scope.angularForm.default_verify.$valid)) {
      return true;
    } else if(($scope.currentTab == "amqp") &&
      ($scope.emsCommonModel.hostname) &&
      ($scope.emsCommonModel.amqp_userid != '' && $scope.angularForm.amqp_userid.$valid &&
       $scope.emsCommonModel.amqp_password != '' && $scope.angularForm.amqp_password.$valid &&
       $scope.emsCommonModel.amqp_verify != '' && $scope.angularForm.amqp_verify.$valid)) {
      return true;
    } else if(($scope.currentTab == "default" && $scope.emsCommonModel.emstype == "azure") &&
      ($scope.emsCommonModel.tenant_id != '' && $scope.angularForm.tenant_id.$valid) &&
      ($scope.emsCommonModel.default_userid != '' && $scope.angularForm.default_userid.$valid &&
       $scope.emsCommonModel.default_password != '' && $scope.angularForm.default_password.$valid &&
       $scope.emsCommonModel.default_verify != '' && $scope.angularForm.default_verify.$valid)) {
      return true;
    }
    else
      return false;
  };

  var emsCommonEditButtonClicked = function(buttonName, serializeFields) {
    miqService.sparkleOn();
    var url = $scope.updateUrl + emsCommonFormId + '?button=' + buttonName;
    if (serializeFields === undefined) {
      miqService.miqAjaxButton(url);
    } else {
      miqService.miqAjaxButton(url, serializeFields);
    }
  };

  var emsCommonAddButtonClicked = function(buttonName, serializeFields) {
    miqService.sparkleOn();
    var url = $scope.createUrl + emsCommonFormId + '?button=' + buttonName;
    if (serializeFields === undefined) {
      miqService.miqAjaxButton(url);
    } else {
      miqService.miqAjaxButton(url, serializeFields);
    }
  };

  $scope.cancelClicked = function() {
    if($scope.newRecord)
      emsCommonAddButtonClicked('cancel');
    else
      emsCommonEditButtonClicked('cancel');

    $scope.angularForm.$setPristine(true);
  };

  $scope.resetClicked = function() {
    $scope.emsCommonModel = angular.copy( $scope.modelCopy );
    $scope.angularForm.$setPristine(true);
    miqService.miqFlash("warn", "All changes have been reset");
  };

  $scope.saveClicked = function() {
    emsCommonEditButtonClicked('save', true);
    $scope.angularForm.$setPristine(true);
  };

  $scope.addClicked = function() {
    emsCommonAddButtonClicked('add', true);
    $scope.angularForm.$setPristine(true);
  };

  $scope.$watch('$viewContentLoaded', function() {
    $scope.afterGet = true;
  });

  init();
}]);

