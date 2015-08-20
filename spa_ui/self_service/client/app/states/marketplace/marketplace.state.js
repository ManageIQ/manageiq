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
      'marketplace': {
        parent: 'application',
        url: '/marketplace',
        redirectTo: 'marketplace.list',
        template: '<ui-view></ui-view>'
      }
    };
  }
})();
