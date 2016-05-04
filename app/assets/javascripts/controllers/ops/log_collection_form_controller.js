ManageIQ.angular.app.controller('logCollectionFormController', ['$http', '$scope', 'serverId', '$attrs', 'miqService', 'miqDBBackupService', function($http, $scope, serverId, $attrs, miqService, miqDBBackupService) {
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
    $scope.validateClicked = miqService.validateWithAjax;
    $scope.model = 'logCollectionModel';

    ManageIQ.angular.scope = $scope;

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

        if($scope.logCollectionModel.log_userid != '') {
          $scope.logCollectionModel.log_password = $scope.logCollectionModel.log_verify = miqService.storedPasswordPlaceholder;
        }

        $scope.afterGet = true;
        $scope.modelCopy = angular.copy( $scope.logCollectionModel );

        miqService.sparkleOff();
      });
    }
  };

  $scope.logProtocolChanged = function() {
    $scope.$broadcast('setNewRecord');

    if(miqDBBackupService.knownProtocolsList.indexOf($scope.logCollectionModel.log_protocol) == -1 &&
       $scope.logCollectionModel.log_protocol != '') {
      url = $scope.logProtocolChangedUrl;
      miqService.sparkleOn();
      $http.get(url + serverId + '?log_protocol=' + $scope.logCollectionModel.log_protocol).success(function (data) {
        $scope.logCollectionModel.depot_name = data.depot_name;
        $scope.logCollectionModel.uri = data.uri;
        $scope.logCollectionModel.uri_prefix = data.uri_prefix;
        miqService.sparkleOff();
      });
    }
    $scope.$broadcast('reactiveFocus');
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
    $scope.$broadcast('resetClicked');
    $scope.logCollectionModel = angular.copy( $scope.modelCopy );
    $scope.angularForm.$setPristine(true);
    miqService.miqFlash("warn", __("All changes have been reset"));
  };

  $scope.cancelClicked = function() {
    miqService.sparkleOn();
    var url = $scope.saveUrl + serverId + '?button=cancel';
    miqService.miqAjaxButton(url, true);
    $scope.angularForm.$setPristine(true);
  };

  $scope.canValidateBasicInfo = function () {
    if ($scope.isBasicInfoValid())
      return true;
    else
      return false;
  }

  init();
}]);
