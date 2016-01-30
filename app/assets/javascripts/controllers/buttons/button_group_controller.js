ManageIQ.angularApplication.controller('buttonGroupController', ['$http', '$scope', 'miqService', function($http, $scope, miqService) {
  var init = function() {
    $scope.saveable = miqService.saveable;
    $scope.disabledClick = miqService.disabledClick;
  };
  init();
}]);
