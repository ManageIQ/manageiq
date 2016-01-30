ManageIQ.angularApplication.directive('startFormDiv', ['$timeout', function($timeout) {
  return {
    link: function(scope, elem, attr) {
      scope.$watch(scope['afterGet'], function() {
        $timeout(function () {
          angular.element('#' + attr.startFormDiv).show();
        });
      });
    },
  };
}]);
