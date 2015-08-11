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
      'projects': {
        url: '/projects',
        redirectTo: 'projects.list',
        template: '<ui-view></ui-view>'
      }
    };
  }

  function navItems() {
    return {};
  }

  function sidebarItems() {
    return {
      //'projects': {
      //  type: 'state',
      //  state: 'projects',
      //  label: 'Projects',
      //  style: 'projects',
      //  order: 1
      //}
    };
  }
})();
