ManageIQ.angular.app.controller('buttonGroupController', ['$http', '$scope', 'miqService', function($http, $scope, miqService) {
  var init = function() {
    $scope.saveable = miqService.saveable;
    $scope.disabledClick = miqService.disabledClick;
    $scope.addText = __("Add");
    $scope.saveText = __("Save");
    $scope.resetText = __("Reset");
    $scope.cancelText = __("Cancel");
  };
  init();
}]);
