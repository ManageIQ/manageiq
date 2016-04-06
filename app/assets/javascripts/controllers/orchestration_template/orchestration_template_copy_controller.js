ManageIQ.angular.app.controller('orchestrationTemplateCopyController', ['$http', '$scope', '$timeout', 'stackId', 'miqService', function($http, $scope, $timeout, stackId, miqService) {
  $scope.stackId = stackId;
  $scope.templateInfo = {
    templateId: null,
    templateName: null,
    templateDescription: null,
    templateDraft: null,
    templateContent: null
  };
  $scope.modelCopy = _.extend({}, $scope.templateInfo);
  $scope.model = 'templateInfo';
  $scope.newRecord = true;
  $scope.saveable = miqService.saveable;

  $http.get('/orchestration_stack/stacks_orchestration_template_info/' + stackId).success(function(response) {
    $scope.templateInfo.templateId = response.template_id;
    $scope.templateInfo.templateName = "Copy of " + response.template_name;
    $scope.templateInfo.templateDescription = response.template_description;
    $scope.templateInfo.templateDraft = response.template_draft;
    $scope.templateInfo.templateContent = response.template_content;
    $scope.modelCopy = _.extend({}, $scope.templateInfo);
  });

  $scope.$watch('templateInfo.templateContent', function() {
    if ($scope.templateInfo.templateContent != null) {
      ManageIQ.editor.getDoc().setValue($scope.templateInfo.templateContent);
    }
  });

  $scope.cancelClicked = function() {
    miqService.sparkleOn();
    miqService.miqAjaxButton('/orchestration_stack/stacks_ot_copy?button=cancel', {});
  };

  $scope.addClicked = function() {
    miqService.sparkleOn();
    miqService.miqAjaxButton('/orchestration_stack/stacks_ot_copy?button=add', $scope.templateInfo);
  };

  $scope.contentChanged = function() {
    return ($scope.modelCopy.templateContent != $scope.templateInfo.templateContent);
  }
}]);
