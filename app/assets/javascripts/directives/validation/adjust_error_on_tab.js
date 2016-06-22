ManageIQ.angular.app.directive('adjustErrorOnTab', ['$rootScope', function($rootScope) {
  return {
    link: function (scope, elem, attrs) {
      scope.$watch(attrs.adjustErrorOnTab, function(value) {
        if (value === true) {
          $rootScope.$broadcast('clearErrorOnTab', {tab: attrs.prefix});
        } else if (value === false) {
          $rootScope.$broadcast('setErrorOnTab', {tab: attrs.prefix});
        }
      });
    }
  }
}]);
