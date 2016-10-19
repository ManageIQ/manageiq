ManageIQ.angular.app.controller('cloudVolumeFormController', ['$http', '$scope', 'cloudVolumeFormId', 'miqService', function($http, $scope, cloudVolumeFormId, miqService) {
  $scope.cloudVolumeModel = { name: '' };
  $scope.formId = cloudVolumeFormId;
  $scope.afterGet = false;
  $scope.modelCopy = angular.copy( $scope.cloudVolumeModel );
  $scope.model = "cloudVolumeModel";

  ManageIQ.angular.scope = $scope;

  if (cloudVolumeFormId == 'new') {
    $scope.cloudVolumeModel.name = "";
  } else {
    miqService.sparkleOn();

    $http.get('/cloud_volume/cloud_volume_form_fields/' + cloudVolumeFormId).success(function(data) {
      $scope.afterGet = true;
      $scope.cloudVolumeModel.name = data.name;

      $scope.modelCopy = angular.copy( $scope.cloudVolumeModel );
      miqService.sparkleOff();
    });
  }

  $scope.addClicked = function() {
    var url = 'create/new' + '?button=add';
    miqService.miqAjaxButton(url, $scope.cloudVolumeModel, { complete: false });
  };

  $scope.cancelClicked = function() {
    if (cloudVolumeFormId == 'new') {
      var url = '/cloud_volume/create/new' + '?button=cancel';
    } else {
      var url = '/cloud_volume/update/' + cloudVolumeFormId + '?button=cancel';
    }
    miqService.miqAjaxButton(url);
  };

  $scope.saveClicked = function() {
    var url = '/cloud_volume/update/' + cloudVolumeFormId + '?button=save';
    miqService.miqAjaxButton(url, $scope.cloudVolumeModel, { complete: false });
  };

  $scope.attachClicked = function() {
    var url = '/cloud_volume/attach_volume/' + cloudVolumeFormId + '?button=attach';
    miqService.miqAjaxButton(url, $scope.cloudVolumeModel, { complete: false });
  };

  $scope.detachClicked = function() {
    var url = '/cloud_volume/detach_volume/' + cloudVolumeFormId + '?button=detach';
    miqService.miqAjaxButton(url, $scope.cloudVolumeModel, { complete: false });
  };

  $scope.cancelAttachClicked = function() {
    miqService.sparkleOn();
    var url = '/cloud_volume/attach_volume/' + cloudVolumeFormId + '?button=cancel';
    miqService.miqAjaxButton(url);
  };

  $scope.cancelDetachClicked = function() {
    var url = '/cloud_volume/detach_volume/' + cloudVolumeFormId + '?button=cancel';
    miqService.miqAjaxButton(url);
  };

  $scope.backupCreateClicked = function() {
    var url = '/cloud_volume/backup_create/' + cloudVolumeFormId + '?button=create';
    miqService.miqAjaxButton(url, $scope.cloudVolumeModel, { complete: false });
  };

  $scope.cancelBackupCreateClicked = function() {
    var url = '/cloud_volume/backup_create/' + cloudVolumeFormId + '?button=cancel';
    miqService.miqAjaxButton(url);
  };

  $scope.backupRestoreClicked = function() {
    var url = '/cloud_volume/backup_restore/' + cloudVolumeFormId + '?button=restore';
    miqService.miqAjaxButton(url, $scope.cloudVolumeModel, { complete: false });
  };

  $scope.cancelBackupRestoreClicked = function() {
    var url = '/cloud_volume/backup_restore/' + cloudVolumeFormId + '?button=cancel';
    miqService.miqAjaxButton(url);
  };

  $scope.resetClicked = function() {
    $scope.cloudVolumeModel = angular.copy( $scope.modelCopy );
    $scope.angularForm.$setPristine(true);
    miqService.miqFlash("warn", "All changes have been reset");
  };
}]);
