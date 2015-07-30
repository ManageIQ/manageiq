(function() {
  'use strict';

  angular.module('app.states')
    .run(appRun);

  /** @ngInject */
  function appRun(routerHelper) {
    var otherwise = '/404';
    routerHelper.configureStates(getStates(), otherwise);
  }

  function getStates() {
    return {
      '404': {
        url: '/404',
        templateUrl: 'app/states/404/404.html',
        title: '404',
        data: {
          layout: 'blank'
        }
      }
    };
  }
})();
