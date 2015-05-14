miqAngularApplication.controller('logCollectionFormController', ['$http', '$scope', 'serverId', '$attrs', 'miqService', 'miqDBBackupService', function($http, $scope, serverId, $attrs, miqService, miqDBBackupService) {
  var init = function() {

    $scope.logCollectionModel = {
      depot_name: '',
      uri: '',
      uri_prefix: '',
      log_protocol: '',
      log_userid: '',
      log_password: '',
      log_verify: '',
      rh_dropbox_depot_name: '',
      rh_dropbox_uri: ''
    };
    $scope.afterGet = true;
    $scope.modelCopy = angular.copy( $scope.logCollectionModel );
    $scope.logCollectionFormFieldsUrl = $attrs.logCollectionFormFieldsUrl;
    $scope.saveUrl = $attrs.saveUrl;

    miqAngularApplication.$scope = $scope;

    if (serverId == 'new') {
      $scope.logCollectionModel.depot_name = '';
      $scope.logCollectionModel.uri = '';
      $scope.logCollectionModel.uri_prefix = '';
      $scope.logCollectionModel.log_userid = '';
      $scope.logCollectionModel.log_password = '';
      $scope.logCollectionModel.log_verify = '';
      $scope.logCollectionModel.log_protocol = '';
      $scope.modelCopy = angular.copy( $scope.logCollectionModel );
    } else {
      $scope.newRecord = false;

      miqService.sparkleOn();

      url = $scope.logCollectionFormFieldsUrl;
      $http.get(url + serverId).success(function(data) {
        $scope.logCollectionModel.log_protocol = data.log_protocol;
        $scope.logCollectionModel.depot_name = data.depot_name;
        $scope.logCollectionModel.uri = data.uri;
        $scope.logCollectionModel.uri_prefix = data.uri_prefix;
        $scope.logCollectionModel.log_userid = data.log_userid;
        $scope.logCollectionModel.log_password = data.log_password;
        $scope.logCollectionModel.log_verify = data.log_verify;

        $scope.logCollectionModel.rh_dropbox_depot_name = data.rh_dropbox_depot_name;
        $scope.logCollectionModel.rh_dropbox_uri = data.rh_dropbox_uri;

        $scope.afterGet = true;
        $scope.modelCopy = angular.copy( $scope.logCollectionModel );

        miqService.sparkleOff();
      });
    }

    $scope.$watch("logCollectionModel.depot_name", function() {
      $scope.form = $scope.angularForm;
      $scope.miqService = miqService;
      $scope.miqDBBackupService = miqDBBackupService;
    });
  };

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

  $scope.saveClicked = function() {
    miqService.sparkleOn();
    var url = $scope.saveUrl + serverId + '?button=save';
    delete $scope.logCollectionModel['rh_dropbox_depot_name'];
    delete $scope.logCollectionModel['rh_dropbox_uri'];
    moreUrlParams = $.param(miqService.serializeModel($scope.logCollectionModel));
    if(moreUrlParams)
      url += '&' + decodeURIComponent(moreUrlParams);
    miqService.miqAjaxButton(url, false);
    $scope.angularForm.$setPristine(true);
  };

  $scope.resetClicked = function() {
    $scope.logCollectionModel = angular.copy( $scope.modelCopy );
    $scope.angularForm.$setPristine(true);
    miqService.miqFlash("warn", "All changes have been reset");
  };

  $scope.cancelClicked = function() {
    miqService.sparkleOn();
    var url = $scope.saveUrl + serverId + '?button=cancel';
    miqService.miqAjaxButton(url, true);
    $scope.angularForm.$setPristine(true);
  };

  init();
}]);
