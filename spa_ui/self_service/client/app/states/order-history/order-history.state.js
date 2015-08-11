(function() {
  'use strict';

  angular.module('app.states')
    .run(appRun);

  /** @ngInject */
  function appRun(routerHelper, navigationHelper) {
    routerHelper.configureStates(getStates());
    navigationHelper.navItems(navItems());
    navigationHelper.sidebarItems(sidebarItems());
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

  function navItems() {
    return {};
  }

  function sidebarItems() {
    return {
      'order-history': {
        type: 'state',
        state: 'order-history',
        label: 'My Requests',
        style: 'order-history',
        order: 2
      }
    };
  }
})();
