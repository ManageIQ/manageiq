ManageIQ.angularApplication.controller('diagnosticsDatabaseFormController', ['$http', '$scope', '$attrs', 'miqService', 'miqDBBackupService', function($http, $scope, $attrs, miqService, miqDBBackupService) {
    var init = function() {

        $scope.diagnosticsDatabaseModel = {
          action_typ: 'db_backup',
          backup_schedule_type: '',
          depot_name: '',
          uri: '',
          uri_prefix: '',
          log_protocol: '',
          log_userid: '',
          log_password: '',
          log_verify: ''
        };
        $scope.afterGet = true;
        $scope.modelCopy = angular.copy( $scope.diagnosticsDatabaseModel );
        $scope.dbBackupFormFieldChangedUrl = $attrs.dbBackupFormFieldChangedUrl;
        $scope.submitUrl = $attrs.submitUrl;

        ManageIQ.angularApplication.$scope = $scope;

        $scope.$watch("diagnosticsDatabaseModel.depot_name", function() {
            $scope.form = $scope.angularForm;
            $scope.miqService = miqService;
            $scope.miqDBBackupService = miqDBBackupService;
        });
    };

    $scope.backupScheduleTypeChanged = function() {
      if($scope.diagnosticsDatabaseModel.backup_schedule_type == '') {
        $scope.diagnosticsDatabaseModel.depot_name = '';
        $scope.diagnosticsDatabaseModel.uri = '';
        $scope.diagnosticsDatabaseModel.uri_prefix = '';
        $scope.diagnosticsDatabaseModel.log_userid = '';
        $scope.diagnosticsDatabaseModel.log_password = '';
        $scope.diagnosticsDatabaseModel.log_verify = '';
        $scope.diagnosticsDatabaseModel.log_protocol = '';
        return;
      }

      miqService.sparkleOn();

      url = $scope.dbBackupFormFieldChangedUrl;
      $http.post(url + $scope.diagnosticsDatabaseModel.backup_schedule_type).success(function(data) {
        $scope.diagnosticsDatabaseModel.depot_name = data.depot_name;
        $scope.diagnosticsDatabaseModel.uri = data.uri;
        $scope.diagnosticsDatabaseModel.uri_prefix = data.uri_prefix;
        $scope.diagnosticsDatabaseModel.log_userid = data.log_userid;
        $scope.diagnosticsDatabaseModel.log_password = data.log_password;
        $scope.diagnosticsDatabaseModel.log_verify = data.log_verify;

        if($scope.diagnosticsDatabaseModel.uri_prefix == 'nfs')
          $scope.diagnosticsDatabaseModel.log_protocol = 'Network File System';
        else
          $scope.diagnosticsDatabaseModel.log_protocol = 'Samba';

        $scope.diagnosticsDatabaseModel.action_typ = 'db_backup';

        miqService.sparkleOff();
      });
    };

    $scope.showSubmitButton = function() {
      return true;
    }

    $scope.isBasicInfoValid = function() {
        if($scope.angularForm.depot_name.$valid &&
            $scope.angularForm.uri.$valid &&
            $scope.angularForm.log_userid.$valid &&
            $scope.angularForm.log_password.$valid &&
            $scope.angularForm.log_verify.$valid)
            return true;
        else
            return false;
    };

    $scope.submitButtonClicked = function(confirm_msg) {
      if (confirm(confirm_msg)) {
        miqService.sparkleOn();
        url = $scope.submitUrl;
        miqService.miqAjaxButton(url, true);
      }
    };

    init();
}]);



