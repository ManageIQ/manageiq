ManageIQ.angularApplication.controller('logCollectionFormController', ['$http', '$scope', 'serverId', '$attrs', 'miqService', 'miqDBBackupService', function($http, $scope, serverId, $attrs, miqService, miqDBBackupService) {
  var init = function() {

    $scope.logCollectionModel = {
      depot_name: '',
      uri: '',
      uri_prefix: '',
      log_protocol: '',
      log_userid: '',
      log_password: '',
      log_verify: ''
    };
    $scope.afterGet = true;
    $scope.modelCopy = angular.copy( $scope.logCollectionModel );
    $scope.logCollectionFormFieldsUrl = $attrs.logCollectionFormFieldsUrl;
    $scope.logProtocolChangedUrl = $attrs.logProtocolChangedUrl;
    $scope.saveUrl = $attrs.saveUrl;
    $scope.model = 'logCollectionModel';

    ManageIQ.angularApplication.$scope = $scope;

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

        $scope.afterGet = true;
        $scope.modelCopy = angular.copy( $scope.logCollectionModel );

        miqService.sparkleOff();
      });
    }

    $scope.$watch("logCollectionModel.depot_name", function() {
      $scope.form = $scope.angularForm;
      $scope.miqDBBackupService = miqDBBackupService;
    });
  };

  $scope.logProtocolChanged = function() {
    if(miqDBBackupService.knownProtocolsList.indexOf($scope.logCollectionModel.log_protocol) == -1) {
      url = $scope.logProtocolChangedUrl;
      miqService.sparkleOn();
      $http.get(url + serverId + '?log_protocol=' + $scope.logCollectionModel.log_protocol).success(function (data) {
        $scope.logCollectionModel.depot_name = data.depot_name;
        $scope.logCollectionModel.uri = data.uri;
        $scope.logCollectionModel.uri_prefix = data.uri_prefix;
        miqService.sparkleOff();
      });
    }
    miqDBBackupService.logProtocolChanged($scope.logCollectionModel);
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
