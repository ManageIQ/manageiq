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
      'admin.alerts': {
        url: '/alerts',
        redirectTo: 'admin.alerts.list',
        template: '<ui-view></ui-view>'
      }
    };
  }

  function navItems() {
    return {};
  }

  function sidebarItems() {
    return {
      'admin.alerts': {
        type: 'state',
        state: 'admin.alerts',
        label: 'Alerts',
        order: 1
      }
    };
  }
})();
