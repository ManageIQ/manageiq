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
      'admin.products.list': {
        url: '', // No url, this state is the index of admin.products
        templateUrl: 'app/states/admin/products/list/list.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Admin Products List',
        resolve: {
          products: resolveProducts
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
  function resolveProducts(Product) {
    return Product.query().$promise;
  }

  /** @ngInject */
  function StateController(logger, $q, products, $state) {
    var vm = this;

    vm.title = 'Admin Products List';
    vm.products = products;

    vm.activate = activate;
    vm.createType = createType;

    activate();

    function activate() {
      logger.info('Activated Admin Products List View');
    }

    function createType(productType) {
      $state.go('admin.products.create', {productType: productType});
    }
  }
})();
