ManageIQ.angularApplication.controller('hostFormController', ['$http', '$scope', '$attrs', 'hostFormId', 'miqService', function($http, $scope, $attrs, hostFormId, miqService) {
  var init = function() {
    $scope.hostModel = {
      name: '',
      hostname: '',
      ipmi_address: '',
      custom_1: '',
      user_assigned_os: '',
      operating_system: false,
      mac_address: '',
      default_userid: '',
      default_password: '',
      default_verify: '',
      remote_userid: '',
      remote_password: '',
      remote_verify: '',
      ws_userid: '',
      ws_password: '',
      ws_verify: '',
      ipmi_userid: '',
      ipmi_password: '',
      ipmi_verify: '',
      validate_id: '',
    };

    $scope.modelCopy = angular.copy( $scope.hostModel );
    $scope.afterGet = false;
    $scope.formId = hostFormId;
    $scope.validateClicked = miqService.validateWithAjax;
    $scope.formFieldsUrl = $attrs.formFieldsUrl;
    $scope.createUrl = $attrs.createUrl;
    $scope.updateUrl = $attrs.updateUrl;
    ManageIQ.angularApplication.$scope = $scope;

    if (hostFormId == 'new') {
      $scope.newRecord = true;
      $scope.hostModel.name = "";
      $scope.hostModel.hostname = "";
      $scope.hostModel.ipmi_address = "";
      $scope.hostModel.custom_1 = "";
      $scope.hostModel.user_assigned_os = "";
      $scope.hostModel.operating_system = false;
      $scope.hostModel.mac_address = "";
      $scope.hostModel.default_userid = "";
      $scope.hostModel.default_password = "";
      $scope.hostModel.default_verify = "";
      $scope.hostModel.remote_userid = "";
      $scope.hostModel.remote_password = "";
      $scope.hostModel.remote_verify = "";
      $scope.hostModel.ws_userid = "";
      $scope.hostModel.ws_password = "";
      $scope.hostModel.ws_verify = "";
      $scope.hostModel.ipmi_userid = "";
      $scope.hostModel.ipmi_password = "";
      $scope.hostModel.ipmi_verify = "";
      $scope.hostModel.validate_id = "";
      $scope.afterGet = true;

    } else if (hostFormId.split(",").length == 1) {
        miqService.sparkleOn();
        $http.get($scope.formFieldsUrl + hostFormId).success(function (data) {
          $scope.hostModel.name = data.name;
          $scope.hostModel.hostname = data.hostname;
          $scope.hostModel.ipmi_address = data.ipmi_address;
          $scope.hostModel.custom_1 = data.custom_1;
          $scope.hostModel.user_assigned_os = data.user_assigned_os;
          $scope.hostModel.operating_system = data.operating_system;
          $scope.hostModel.mac_address = data.mac_address;
          $scope.hostModel.default_userid = data.default_userid;
          $scope.hostModel.default_password = data.default_password;
          $scope.hostModel.default_verify = data.default_verify;
          $scope.hostModel.remote_userid = data.remote_userid;
          $scope.hostModel.remote_password = data.remote_password;
          $scope.hostModel.remote_verify = data.remote_verify;
          $scope.hostModel.ws_userid = data.ws_userid;
          $scope.hostModel.ws_password = data.ws_password;
          $scope.hostModel.ws_verify = data.ws_verify;
          $scope.hostModel.ipmi_userid = data.ipmi_userid;
          $scope.hostModel.ipmi_password = data.ipmi_password;
          $scope.hostModel.ipmi_verify = data.ipmi_verify;
          $scope.hostModel.validate_id = data.validate_id;

          $scope.afterGet = true;

          $scope.modelCopy = angular.copy( $scope.hostModel );
          miqService.sparkleOff();
        });
     } else if (hostFormId.split(",").length > 1) {
      $scope.afterGet = true;
    }

     $scope.currentTab = "default";

    $scope.$watch("hostModel.name", function() {
      $scope.form = $scope.angularForm;
      $scope.model = "hostModel";
    });
  };

  $scope.changeAuthTab = function(id) {
    $scope.currentTab = id;
  }

  $scope.addClicked = function() {
    miqService.sparkleOn();
    var url = 'create/new' + '?button=add';
    miqService.miqAjaxButton(url, true);
  };

  $scope.cancelClicked = function() {
    miqService.sparkleOn();
    if (hostFormId == 'new') {
      var url = $scope.createUrl + 'new?button=cancel';
    }
    else if (hostFormId.split(",").length == 1) {
      var url = $scope.updateUrl + hostFormId + '?button=cancel';
    }
    else if (hostFormId.split(",").length > 1) {
      var url = $scope.updateUrl + '?button=cancel';
    }
    miqService.miqAjaxButton(url);
  };

  $scope.saveClicked = function() {
    miqService.sparkleOn();
    if (hostFormId.split(",").length > 1) {
      var url = $scope.updateUrl + '?button=save';
    }
    else {
      var url = $scope.updateUrl + hostFormId + '?button=save';
    }
    miqService.miqAjaxButton(url, true);
  };

  $scope.resetClicked = function() {
    $scope.hostModel = angular.copy( $scope.modelCopy );
    $scope.angularForm.$setUntouched(true);
    $scope.angularForm.$setPristine(true);
    miqService.miqFlash("warn", "All changes have been reset");
  };

  var setFormToValid = function() {
    for (var name in $scope.angularForm) {
      if($scope.angularForm[name].$name == name)
        $scope.angularForm[name].$setValidity('miqrequired', true);
      }
    }

  $scope.isBasicInfoValid = function() {
    if(($scope.currentTab == "default") &&
      ($scope.hostModel.hostname || $scope.hostModel.validate_id) &&
      ($scope.hostModel.default_userid != '' && $scope.angularForm.default_userid.$valid &&
       $scope.hostModel.default_password != '' && $scope.angularForm.default_password.$valid &&
      $scope.hostModel.default_verify != '' && $scope.angularForm.default_verify.$valid)) {
        return true;
    } else if(($scope.currentTab == "remote") &&
      ($scope.hostModel.hostname || $scope.hostModel.validate_id) &&
      ($scope.hostModel.remote_userid != '' && $scope.angularForm.remote_userid.$valid &&
       $scope.hostModel.remote_password != '' && $scope.angularForm.remote_password.$valid &&
      $scope.hostModel.remote_verify != '' && $scope.angularForm.remote_verify.$valid)) {
      return true;
    } else if(($scope.currentTab == "ws") &&
      ($scope.hostModel.hostname || $scope.hostModel.validate_id) &&
      ($scope.hostModel.ws_userid != '' && $scope.angularForm.ws_userid.$valid &&
       $scope.hostModel.ws_password != '' && $scope.angularForm.ws_password.$valid &&
      $scope.hostModel.ws_verify != '' && $scope.angularForm.ws_verify.$valid)) {
      return true;
    } else if(($scope.currentTab == "ipmi") &&
      ($scope.hostModel.ipmi_address) &&
      ($scope.hostModel.ipmi_userid != '' && $scope.angularForm.ipmi_userid.$valid &&
       $scope.hostModel.ipmi_password != '' && $scope.angularForm.ipmi_password.$valid &&
      $scope.hostModel.ipmi_verify != '' && $scope.angularForm.ipmi_verify.$valid)) {
      return true;
    } else
      return false;
  };

  $scope.canValidate = function () {
    if ($scope.isBasicInfoValid() && $scope.validateFieldsDirty())
      return true;
    else
      return false;
  }

  $scope.canValidateBasicInfo = function () {
    if ($scope.isBasicInfoValid())
      return true;
    else
      return false;
  }

  $scope.validateFieldsDirty = function () {
    if(($scope.currentTab == "default") &&
      (($scope.angularForm.hostname.$dirty || $scope.angularForm.validate_id.$dirty) &&
      $scope.angularForm.default_userid.$dirty &&
      $scope.angularForm.default_password.$dirty &&
      $scope.angularForm.default_verify.$dirty)) {
      return true;
    } else if(($scope.currentTab == "remote") &&
      (($scope.angularForm.hostname.$dirty || $scope.angularForm.validate_id.$dirty) &&
      $scope.angularForm.remote_userid.$dirty &&
      $scope.angularForm.remote_password.$dirty &&
      $scope.angularForm.remote_verify.$dirty)) {
      return true;
    } else if(($scope.currentTab == "ws") &&
      (($scope.angularForm.hostname.$dirty || $scope.angularForm.validate_id.$dirty) &&
      $scope.angularForm.ws_userid.$dirty &&
      $scope.angularForm.ws_password.$dirty &&
      $scope.angularForm.ws_verify.$dirty)) {
      return true;
    } else if(($scope.currentTab == "ipmi") &&
      ($scope.angularForm.ipmi_address.$dirty &&
      $scope.angularForm.ipmi_userid.$dirty &&
      $scope.angularForm.ipmi_password.$dirty &&
      $scope.angularForm.ipmi_verify.$dirty)) {
      return true;
    } else
      return false;
  }

  init();
}]);
