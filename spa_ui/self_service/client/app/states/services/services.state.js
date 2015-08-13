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
      'services': {
        url: '/services',
        redirectTo: 'services.list',
        template: '<ui-view></ui-view>'
      }
    };
  }
})();
