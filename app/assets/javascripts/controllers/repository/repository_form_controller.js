miqAngularApplication.controller('repositoryFormController', ['$http', '$scope', 'repositoryFormId', 'miqService', function($http, $scope, repositoryFormId, miqService) {
  $scope.repoModel = { repo_name: '', repo_path: '' };
  $scope.path_type = '';
  $scope.formId = repositoryFormId;
  $scope.afterGet = false;
  $scope.modelCopy = angular.copy( $scope.repoModel );

  miqAngularApplication.$scope = $scope;

  if (repositoryFormId == 'new') {
    $scope.repoModel.repo_name = "";
    $scope.repoModel.repo_path = "";
  } else {
      miqService.sparkleOn();

      $http.get('/repository/repository_form_fields/' + repositoryFormId).success(function(data) {
        $scope.afterGet = true;
        $scope.repoModel.repo_name = data.repo_name;
        $scope.repoModel.repo_path = data.repo_path;

        $scope.modelCopy = angular.copy( $scope.repoModel );
        miqService.sparkleOff();
      });
   }

  $scope.$watch("repoModel.repo_name", function() {
    $scope.form = $scope.repositoryForm;
    $scope.miqService = miqService;
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
    $scope.repositoryForm.$setPristine(true);
    miqService.miqFlash("warn", "All changes have been reset");
  };
}]);
