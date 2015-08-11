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
      'admin': {
        abstract: true,
        template: '<ui-view></ui-view>',
        url: '/admin'
      }
    };
  }

  function navItems() {
    return {};
  }

  function sidebarItems() {
    return {
      //'admin': {
      //  type: 'dropdown',
      //  state: 'admin',
      //  label: 'Admin',
      //  style: 'admin',
      //  order: 6,
      //  isVisible: isVisible
      //}
    };
  }

  /** @ngInject */
  function isVisible(SessionService) {
    return SessionService.role === 'admin';
  }
})();
