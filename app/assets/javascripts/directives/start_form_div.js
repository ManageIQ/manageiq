ManageIQ.angular.app.directive('startFormDiv', ['$timeout', function($timeout) {
  return {
    link: function(scope, _elem, attr) {
      scope.$watch(scope['afterGet'], function() {
        $timeout(function () {
          angular.element('#' + attr.startFormDiv).show();
        });
      });
    },
  };
}]);
