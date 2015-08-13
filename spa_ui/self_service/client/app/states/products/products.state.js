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
      'products': {
        url: '/',
        redirectTo: 'marketplace',
        template: '<ui-view></ui-view>'
      }
    };
  }
})();
