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
      'admin.product-categories': {
        url: '/product-categories',
        redirectTo: 'admin.product-categories.list',
        template: '<ui-view></ui-view>'
      }
    };
  }

  function navItems() {
    return {};
  }

  function sidebarItems() {
    return {
      'admin.product-categories': {
        type: 'state',
        state: 'admin.product-categories',
        label: 'Product Categories',
        order: 4
      }
    };
  }
})();
