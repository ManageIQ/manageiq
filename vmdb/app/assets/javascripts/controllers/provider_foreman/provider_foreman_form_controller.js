miqAngularApplication.controller('providerForemanFormController', ['$http', '$scope', 'providerForemanFormId', 'miqService', function($http, $scope, providerForemanFormId, miqService) {
    var init = function() {
      $scope.providerForemanModel = {
        name: '',
        url: '',
        verify_ssl: '',
        log_userid: '',
        log_password: '',
        log_verify: ''
      };
      $scope.formId = providerForemanFormId;
      $scope.afterGet = false;
      $scope.modelCopy = angular.copy( $scope.providerForemanModel );

      miqAngularApplication.$scope = $scope;

      if (providerForemanFormId == 'new') {
        $scope.newRecord                         = true;
        $scope.providerForemanModel.name         = '';
        $scope.providerForemanModel.url          = '';
        $scope.providerForemanModel.verify_ssl   = '';

        $scope.providerForemanModel.log_userid   = '';
        $scope.providerForemanModel.log_password = '';
        $scope.providerForemanModel.log_verify   = '';
        $scope.afterGet                          = true;
        $scope.modelCopy                         = angular.copy( $scope.providerForemanModel );
      } else {
        $scope.newRecord = false;

        miqService.sparkleOn();

        $http.get('/provider_foreman/provider_foreman_form_fields/' + providerForemanFormId).success(function(data) {
          $scope.providerForemanModel.name        = data.name;
          $scope.providerForemanModel.url         = data.url;
          $scope.providerForemanModel.verify_ssl  = data.verify_ssl;

          $scope.providerForemanModel.log_userid   = data.log_userid;
          $scope.providerForemanModel.log_password = data.log_password;
          $scope.providerForemanModel.log_verify   = data.log_verify;

          if($scope.providerForemanModel.verify_ssl == null)
            $scope.providerForemanModel.verify_ssl = "0";
          else
            $scope.providerForemanModel.verify_ssl = $scope.providerForemanModel.verify_ssl.toString();

          $scope.afterGet = true;
          $scope.modelCopy = angular.copy( $scope.providerForemanModel );

          miqService.sparkleOff();
        });
      }

      $scope.$watch("providerForemanModel.name", function() {
        $scope.form = $scope.angularForm;
        $scope.miqService = miqService;
      });
    };

    $scope.isBasicInfoValid = function() {
      if($scope.angularForm.name.$valid &&
         $scope.angularForm.url.$valid &&
         $scope.angularForm.log_userid.$valid &&
         $scope.angularForm.log_password.$valid &&
         $scope.angularForm.log_verify.$valid)
        return true;
      else
        return false;
    };

    var providerForemanEditButtonClicked = function(buttonName, serializeFields) {
      miqService.sparkleOn();
      var url = '/provider_foreman/edit/' + providerForemanFormId + '?button=' + buttonName;
      if (serializeFields === undefined) {
        miqService.miqAjaxButton(url);
      } else {
        miqService.miqAjaxButton(url, serializeFields);
      }
    };

    $scope.cancelClicked = function() {
      providerForemanEditButtonClicked('cancel');
      $scope.angularForm.$setPristine(true);
    };

    $scope.resetClicked = function() {
      $scope.providerForemanModel = angular.copy( $scope.modelCopy );
      $scope.angularForm.$setPristine(true);
      miqService.miqFlash("warn", "All changes have been reset");
    };

    $scope.saveClicked = function() {
      providerForemanEditButtonClicked('save', true);
      $scope.angularForm.$setPristine(true);
    };

    $scope.addClicked = function() {
      $scope.saveClicked();
    };

    init();
}]);
