ManageIQ.angular.app.controller('providerForemanFormController', ['$http', '$scope', 'providerForemanFormId', 'miqService', function($http, $scope, providerForemanFormId, miqService) {
    var init = function() {
      $scope.providerForemanModel = {
        provtype: '',
        name: '',
        url: '',
        zone: '',
        verify_ssl: '',
        log_userid: '',
        log_password: '',
        log_verify: ''
      };
      $scope.formId = providerForemanFormId;
      $scope.afterGet = false;
      $scope.validateClicked = miqService.validateWithAjax;
      $scope.modelCopy = angular.copy( $scope.providerForemanModel );
      $scope.model = 'providerForemanModel';

      ManageIQ.angular.scope = $scope;

      if (providerForemanFormId == 'new') {
        $scope.newRecord = true;

        $http.get('/provider_foreman/provider_foreman_form_fields/' + providerForemanFormId).success(function(data) {
          $scope.providerForemanModel.provtype = '';
          $scope.providerForemanModel.name = '';
          $scope.providerForemanModel.zone = data.zone;
          $scope.providerForemanModel.url = '';
          $scope.providerForemanModel.verify_ssl = false;

          $scope.providerForemanModel.log_userid = '';
          $scope.providerForemanModel.log_password = '';
          $scope.providerForemanModel.log_verify = '';
          $scope.afterGet = true;
          $scope.modelCopy = angular.copy($scope.providerForemanModel);

        });
      } else {
        $scope.newRecord = false;

        miqService.sparkleOn();

        $http.get('/provider_foreman/provider_foreman_form_fields/' + providerForemanFormId).success(function(data) {
          $scope.providerForemanModel.provtype        = data.provtype;
          $scope.providerForemanModel.name            = data.name;
          $scope.providerForemanModel.zone            = data.zone;
          $scope.providerForemanModel.url             = data.url;
          $scope.providerForemanModel.verify_ssl      = data.verify_ssl == "1";

          $scope.providerForemanModel.log_userid   = data.log_userid;

          if ($scope.providerForemanModel.log_userid !== '') {
            $scope.providerForemanModel.log_password = $scope.providerForemanModel.log_verify = miqService.storedPasswordPlaceholder;
          }

          $scope.afterGet = true;
          $scope.modelCopy = angular.copy( $scope.providerForemanModel );

          miqService.sparkleOff();
        });
      }
    };

    $scope.canValidateBasicInfo = function () {
      return $scope.isBasicInfoValid();
    };

    $scope.isBasicInfoValid = function() {
      return $scope.angularForm.url.$valid &&
        $scope.angularForm.log_userid.$valid &&
        $scope.angularForm.log_password.$valid &&
        $scope.angularForm.log_verify.$valid;
    };

    var providerForemanEditButtonClicked = function(buttonName, data) {
      var url = '/provider_foreman/edit/' + providerForemanFormId + '?button=' + buttonName;

      miqService.sparkleOn();
      miqService.miqAjaxButton(url, data);
    };

    $scope.cancelClicked = function() {
      providerForemanEditButtonClicked('cancel');
      $scope.angularForm.$setPristine(true);
    };

    $scope.resetClicked = function() {
      $scope.$broadcast ('resetClicked');
      $scope.providerForemanModel = angular.copy( $scope.modelCopy );
      $scope.angularForm.$setPristine(true);
      miqService.miqFlash("warn", __("All changes have been reset"));
    };

    $scope.saveClicked = function() {
      providerForemanEditButtonClicked('save', $scope.providerForemanModel);
      $scope.angularForm.$setPristine(true);
    };

    $scope.addClicked = $scope.saveClicked;

    init();
}]);
