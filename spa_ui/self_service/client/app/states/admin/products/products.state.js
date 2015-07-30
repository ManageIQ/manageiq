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
      'admin.products': {
        url: '/products',
        redirectTo: 'admin.products.list',
        template: '<ui-view></ui-view>',
        resolve: {
          productTypes: resolveProductTypes
        }
      }
    };
  }

  function navItems() {
    return {};
  }

  function sidebarItems() {
    return {
      'admin.products': {
        type: 'state',
        state: 'admin.products',
        label: 'Products',
        order: 5
      }
    };
  }

  /** @ngInject */
  function resolveProductTypes(ProductType) {
    return ProductType.query().$promise;
  }
})();
