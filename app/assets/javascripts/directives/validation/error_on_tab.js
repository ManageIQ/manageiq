ManageIQ.angular.app.directive('errorOnTab', ['$timeout', function($timeout) {
  return {
    link: function (scope, elem, attrs) {
      scope.$on('setErrorOnTab', function(e, args) {
        if (elem[0].attributes['error-on-tab'].value === args.tab) {
          $timeout(function (attrs) {
            $(elem[0]).addClass('fa fa-exclamation-circle');
          });
        }
      });

      scope.$on('clearErrorOnTab', function(e, args) {
        if (elem[0].attributes['error-on-tab'].value === args.tab) {
          $timeout(function (attrs) {
            $(elem[0]).removeClass('fa fa-exclamation-circle');
          });
        }
      });
    }
  }
}]);

