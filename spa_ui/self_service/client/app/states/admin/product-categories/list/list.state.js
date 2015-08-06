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
      'admin.product-categories.list': {
        url: '',
        templateUrl: 'app/states/admin/product-categories/list/list.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Admin Product Categories List',
        resolve: {
          productCategories: resolveProductCategories
        }
      }
    };
  }

  function navItems() {
    return {};
  }

  function sidebarItems() {
    return {};
  }

  /** @ngInject */
  function resolveProductCategories(ProductCategory) {
    return ProductCategory.query().$promise;
  }

  /** @ngInject */
  function StateController(logger, productCategories) {
    var vm = this;

    vm.title = 'Admin Product Categories List';
    vm.productCategories = productCategories;

    vm.activate = activate;

    activate();

    function activate() {
      logger.info('Activated Admin Product Categories List View');
    }
  }
})();
