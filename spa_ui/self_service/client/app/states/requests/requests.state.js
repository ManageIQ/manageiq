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
      'requests': {
        parent: 'application',
        url: '/requests',
        redirectTo: 'requests.list',
        template: '<ui-view></ui-view>'
      }
    };
  }
})();
