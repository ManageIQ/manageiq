ManageIQ.angularApplication.controller('repositoryFormController', ['$http', '$scope', 'repositoryFormId', 'miqService', 'repositoryData', function($http, $scope, repositoryFormId, miqService, repositoryData) {
  $scope.repoModel = { repo_name: '', repo_path: '' };
  $scope.path_type = '';
  $scope.formId = repositoryFormId;
  $scope.afterGet = false;
  $scope.modelCopy = angular.copy( $scope.repoModel );

  ManageIQ.angular.scope = $scope;

  if (repositoryFormId == 'new') {
    $scope.newRecord = true;
    $scope.repoModel.repo_name = "";
    $scope.repoModel.repo_path = "";
  } else {
    $scope.newRecord = false;
    $scope.afterGet = true;
    $scope.repoModel.repo_name = repositoryData.data.repo_name;
    $scope.repoModel.repo_path = repositoryData.data.repo_path;

    $scope.modelCopy = angular.copy( $scope.repoModel );
   }

  $scope.$watch("repoModel.repo_name", function() {
    $scope.form = $scope.angularForm;
    $scope.model = "repoModel";
  });

  $scope.addClicked = function() {
    miqService.sparkleOn();
    var url = 'create/new' + '?button=add&path_type=' + $scope.path_type;
    miqService.miqAjaxButton(url, true);
  };

  $scope.cancelClicked = function() {
    miqService.sparkleOn();
    if (repositoryFormId == 'new') {
      var url = '/repository/create/new' + '?button=cancel';
    }
    else {
      var url = '/repository/update/' + repositoryFormId + '?button=cancel';
    }
    miqService.miqAjaxButton(url);
  };

  $scope.saveClicked = function() {
    miqService.sparkleOn();
    var url = '/repository/update/' + repositoryFormId + '?button=save&path_type=' + $scope.path_type;
    miqService.miqAjaxButton(url, true);
  };

  $scope.resetClicked = function() {
    $scope.repoModel = angular.copy( $scope.modelCopy );
    $scope.angularForm.$setUntouched(true);
    $scope.angularForm.$setPristine(true);
    miqService.miqFlash("warn", __("All changes have been reset"));
  };
}]);
