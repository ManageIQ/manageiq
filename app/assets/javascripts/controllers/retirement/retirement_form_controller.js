ManageIQ.angular.app.controller('retirementFormController', ['$http', '$scope', '$timeout', 'objectIds', 'miqService', function($http, $scope, $timeout, objectIds, miqService) {
  $scope.objectIds = objectIds;
  $scope.retirementInfo = {
    retirementDate: null,
    retirementWarning: ''
  };
  $scope.datepickerStartDate = new Date();
  $scope.modelCopy = _.extend({}, $scope.retirementInfo);
  $scope.model = 'retirementInfo';
  $scope.timezone = ManageIQ.timezone || { name: "unknown" };

  if (objectIds.length == 1) {
    $http.get('retirement_info/' + objectIds[0]).success(function(response) {
      if (response.retirement_date != null) {
        $scope.retirementInfo.retirementDate = moment.utc(response.retirement_date, 'MM-DD-YYYY').toDate();
      }
      $scope.retirementInfo.retirementWarning = response.retirement_warning || "";
      $scope.modelCopy = _.extend({}, $scope.retirementInfo);
    });
  }

  $scope.cancelClicked = function() {
    miqService.sparkleOn();
    miqService.miqAjaxButton('retire?button=cancel');
  };

  $scope.saveClicked = function() {
    miqService.sparkleOn();
    miqService.miqAjaxButton('retire?button=save',
                             {'retire_date': $scope.retirementInfo.retirementDate,
                              'retire_warn': $scope.retirementInfo.retirementWarning});
  };
}]);
