(function() {
  'use strict';
  angular.module('app', [
    'app.core',
    'app.config',
    'app.states',
    'ngProgress'
  ]);
  angular.module('app').controller('AppController', ['$rootScope', '$scope', 'ngProgressFactory',
    function($rootScope, $scope, ngProgressFactory) {
      $scope.progressbar = ngProgressFactory.createInstance();
      $scope.progressbar.setColor('#0088ce');
      $scope.progressbar.setHeight('3px');
      $rootScope.$on('$stateChangeStart', function(event, toState, toParams, fromState, fromParams) {
        if (toState.resolve) {
          $scope.progressbar.start();
        }
      });
      $rootScope.$on('$stateChangeSuccess', function(event, toState, toParams, fromState, fromParams) {
        if (toState.resolve) {
          $scope.progressbar.complete();
        }
      });
    }]);
})();
