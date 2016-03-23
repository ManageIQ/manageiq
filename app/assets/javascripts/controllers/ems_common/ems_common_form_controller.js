ManageIQ.angular.app.controller('emsCommonFormController', ['$http', '$scope', '$attrs', 'emsCommonFormId', 'miqService', function($http, $scope, $attrs, emsCommonFormId, miqService) {
  var init = function() {
    $scope.emsCommonModel = {
      name: '',
      emstype: '',
      openstack_infra_providers_exist: false,
      provider_id: '',
      zone: '',
      hostname: '',
      default_hostname: '',
      amqp_hostname: '',
      project: '',
      default_api_port: '',
      amqp_api_port: '',
      api_version: '',
      default_security_protocol: '',
      realm: '',
      security_protocol: '',
      amqp_security_protocol: '',
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
      ssh_keypair_userid: '',
      ssh_keypair_password: '',
      ssh_keypair_verify: '',
      service_account: '',
      emstype_vm: false,
      ems_common: true,
      azure_tenant_id: '',
      subscription: ''
      host_default_vnc_port_start: '',
      host_default_vnc_port_end: ''
    };
    $scope.realmNote = __("Note: Username must be in the format: name@realm");
    $scope.formId = emsCommonFormId;
    $scope.afterGet = false;
    $scope.validateClicked = miqService.validateWithREST;
    $scope.modelCopy = angular.copy( $scope.emsCommonModel );
    $scope.formFieldsUrl = $attrs.formFieldsUrl;
    $scope.createUrl = $attrs.createUrl;
    $scope.updateUrl = $attrs.updateUrl;
    $scope.model = 'emsCommonModel';

    ManageIQ.angular.scope = $scope;

    if (emsCommonFormId == 'new') {
      $scope.newRecord                  = true;

      miqService.sparkleOn();
      $http.get($scope.formFieldsUrl + emsCommonFormId).success(function(data) {
        $scope.emsCommonModel.zone                            = data.zone;
        $scope.emsCommonModel.emstype_vm                      = data.emstype_vm;
        $scope.emsCommonModel.openstack_infra_providers_exist = data.openstack_infra_providers_exist;
        $scope.emsCommonModel.default_api_port                = 5000;
        $scope.emsCommonModel.amqp_api_port                   = 5672;
        $scope.emsCommonModel.api_version                     = 'v2';
        $scope.emsCommonModel.default_security_protocol       = 'ssl';
        $scope.emsCommonModel.amqp_security_protocol          = 'ssl';
        miqService.sparkleOff();
      });
      $scope.afterGet  = true;
      $scope.modelCopy = angular.copy( $scope.emsCommonModel );
    }
    else {
      $scope.newRecord = false;
      miqService.sparkleOn();

      $http.get($scope.formFieldsUrl + emsCommonFormId).success(function(data) {
        $scope.emsCommonModel.name                            = data.name;
        $scope.emsCommonModel.emstype                         = data.emstype;
        $scope.emsCommonModel.zone                            = data.zone;
        $scope.emsCommonModel.hostname                        = data.hostname;
        $scope.emsCommonModel.default_hostname                = data.default_hostname;
        $scope.emsCommonModel.amqp_hostname                   = data.amqp_hostname;
        $scope.emsCommonModel.project                         = data.project;

        $scope.emsCommonModel.openstack_infra_providers_exist = data.openstack_infra_providers_exist;
        $scope.emsCommonModel.provider_id                     = data.provider_id.toString();
        $scope.emsCommonModel.default_api_port                = angular.isDefined(data.default_api_port) && data.default_api_port != '' ? data.default_api_port : '5000';
        $scope.emsCommonModel.amqp_api_port                   = angular.isDefined(data.amqp_api_port) && data.amqp_api_port != '' ? data.amqp_api_port : '5672';
        $scope.emsCommonModel.api_version                     = data.api_version;
        $scope.emsCommonModel.default_security_protocol       = data.default_security_protocol;
        $scope.emsCommonModel.realm                           = data.realm;
        $scope.emsCommonModel.security_protocol               = data.security_protocol;
        $scope.emsCommonModel.amqp_security_protocol          = angular.isDefined(data.amqp_security_protocol) ? data.amqp_security_protocol : 'ssl';
        $scope.emsCommonModel.provider_region                 = data.provider_region;
        $scope.emsCommonModel.default_userid                  = data.default_userid;
        $scope.emsCommonModel.amqp_userid                     = data.amqp_userid;
        $scope.emsCommonModel.service_account                 = data.service_account;
        $scope.emsCommonModel.azure_tenant_id                 = data.azure_tenant_id;
        $scope.emsCommonModel.subscription                    = data.subscription;

        if($scope.emsCommonModel.default_userid != '') {
          $scope.emsCommonModel.default_password = $scope.emsCommonModel.default_verify = miqService.storedPasswordPlaceholder;
        }
        if($scope.emsCommonModel.amqp_userid != '') {
          $scope.emsCommonModel.amqp_password = $scope.emsCommonModel.amqp_verify = miqService.storedPasswordPlaceholder;
        }
        if($scope.emsCommonModel.metrics_userid != '') {
          $scope.emsCommonModel.metrics_password = $scope.emsCommonModel.metrics_verify = miqService.storedPasswordPlaceholder;
        }
        if($scope.emsCommonModel.ssh_keypair_userid != '') {
          $scope.emsCommonModel.ssh_keypair_password = $scope.emsCommonModel.ssh_keypair_verify = miqService.storedPasswordPlaceholder;
        }

        $scope.afterGet  = true;
        $scope.modelCopy = angular.copy( $scope.emsCommonModel );

        miqService.sparkleOff();
      });
    }
    $scope.currentTab = "default";

    $scope.$watch("emsCommonModel.name", function() {
      $scope.form = $scope.angularForm;
      $scope.model = "emsCommonModel";
    });
  };

  $scope.changeAuthTab = function(id) {
    $scope.currentTab = id;
  }

  $scope.canValidateBasicInfo = function () {
    return $scope.isBasicInfoValid()
  }

  $scope.isBasicInfoValid = function() {
    if(($scope.currentTab == "default" && $scope.emsCommonModel.emstype != "azure") &&
      ($scope.emsCommonModel.emstype == "ec2" || ($scope.emsCommonModel.emstype == "openstack" && $scope.emsCommonModel.default_hostname)) &&
      ($scope.emsCommonModel.default_userid != '' && $scope.angularForm.default_userid.$valid &&
       $scope.emsCommonModel.default_password != '' && $scope.angularForm.default_password.$valid &&
       $scope.emsCommonModel.default_verify != '' && $scope.angularForm.default_verify.$valid)) {
      return true;
    } else if(($scope.currentTab == "amqp") &&
      ($scope.emsCommonModel.amqp_hostname) &&
      ($scope.emsCommonModel.amqp_userid != '' && $scope.angularForm.amqp_userid.$valid &&
       $scope.emsCommonModel.amqp_password != '' && $scope.angularForm.amqp_password.$valid &&
       $scope.emsCommonModel.amqp_verify != '' && $scope.angularForm.amqp_verify.$valid)) {
      return true;
    } else if(($scope.currentTab == "default" && $scope.emsCommonModel.emstype == "azure") &&
      ($scope.emsCommonModel.azure_tenant_id != '' && $scope.angularForm.azure_tenant_id.$valid) &&
      ($scope.emsCommonModel.default_userid != '' && $scope.angularForm.default_userid.$valid &&
       $scope.emsCommonModel.default_password != '' && $scope.angularForm.default_password.$valid &&
       $scope.emsCommonModel.default_verify != '' && $scope.angularForm.default_verify.$valid)) {
      return true;
    } else if($scope.emsCommonModel.emstype == "gce" && $scope.emsCommonModel.project != '' &&
      ($scope.currentTab == "default" ||
      ($scope.currentTab == "service_account" && $scope.emsCommonModel.service_account != ''))) {
      return true;
    }
    else
      return false;
  };

  var emsCommonEditButtonClicked = function(buttonName, serializeFields, $event) {
    miqService.sparkleOn();
    var url = $scope.updateUrl + '?button=' + buttonName;
    miqService.restAjaxButton(url, $event.target);
  };

  var emsCommonAddButtonClicked = function(buttonName, serializeFields, $event) {
    miqService.sparkleOn();
    var url = $scope.createUrl + '?button=' + buttonName;
    miqService.restAjaxButton(url, $event.target);
  };

  $scope.cancelClicked = function($event) {
    angular.element('#button_name').val('cancel');
    if($scope.newRecord)
      emsCommonAddButtonClicked('cancel', false, $event);
    else
      emsCommonEditButtonClicked('cancel', false, $event);

    $scope.angularForm.$setPristine(true);
  };

  $scope.resetClicked = function() {
    $scope.$broadcast ('resetClicked');
    $scope.emsCommonModel = angular.copy( $scope.modelCopy );
    $scope.angularForm.$setPristine(true);
    miqService.miqFlash("warn", __("All changes have been reset"));
  };

  $scope.saveClicked = function($event, formSubmit) {
    if(formSubmit) {
      angular.element('#button_name').val('save');
      emsCommonEditButtonClicked('save', true, $event);
      $scope.angularForm.$setPristine(true);
    }
    else {
      $event.preventDefault();
    }
  };

  $scope.addClicked = function($event, formSubmit) {
    if(formSubmit) {
      angular.element('#button_name').val('add');
      emsCommonAddButtonClicked('add', true, $event);
      $scope.angularForm.$setPristine(true);
    }
    else {
      $event.preventDefault();
    }
  };

  $scope.isRegionSupported = function() {
    if ($scope.emsCommonModel.emstype === 'ec2' || $scope.emsCommonModel.emstype === 'azure') {
      return true;
    }

    return false;
  };

  $scope.providerTypeChanged = function() {
    $scope.emsCommonModel.api_port = "";
    $scope.emsCommonModel.security_protocol = "";
    $scope.note = "";
    if ($scope.emsCommonModel.emstype === 'openstack_infra') {
      $scope.emsCommonModel.api_port = "5000";
    } else if ($scope.emsCommonModel.emstype === 'scvmm' && $scope.emsCommonModel.security_protocol === 'kerberos'){
      $scope.note = $scope.realmNote;
    }
  };

  $scope.scvmmSecurityProtocolChanged = function() {
    $scope.note = "";
    if ($scope.emsCommonModel.emstype === 'scvmm' && $scope.emsCommonModel.security_protocol === 'kerberos'){
      $scope.note = $scope.realmNote;
    }
  };

  init();
}]);
