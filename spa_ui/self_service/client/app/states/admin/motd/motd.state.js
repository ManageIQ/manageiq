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
      'admin.motd': {
        url: '/motd',
        redirectTo: 'admin.motd.edit',
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
        state: 'admin.motd',
        label: 'Message of the Day',
        order: 3
      }
    };
  }
})();
