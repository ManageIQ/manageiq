miqHttpInject(angular.module('miq.containers.providersModule')).controller('containers.deployProviderReviewProgressController',
  ['$rootScope', '$scope',
  function($rootScope, $scope) {
    'use strict';

    var firstShow = true;
    $scope.onShow = function () {
      if (firstShow) {
        firstShow = false;
      }
    };
  }
]);
