(function() {
  'use strict';

  angular.module('app.states')
    .run(appRun);

  /** @ngInject */
  function appRun(routerHelper) {
    routerHelper.configureStates(getStates());
  }

  function getStates() {
    return {
      'order-history': {
        url: '/order-history',
        redirectTo: 'order-history.list',
        template: '<ui-view></ui-view>'
      }
    };
  }
})();
