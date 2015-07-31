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
      'admin.products.edit': {
        url: '/edit/:productId',
        templateUrl: 'app/states/admin/products/edit/edit.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Admin Products Edit',
        resolve: {
          product: resolveProduct
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
  function resolveProduct(Product, $stateParams) {
    return Product.get({id: $stateParams.productId, 'methods[]': ['product_type']}).$promise;
  }

  /** @ngInject */
  function StateController(logger, lodash, product, productTypes) {
    var vm = this;

    vm.title = 'Admin Products Edit';
    vm.activate = activate;

    activate();

    function activate() {
      vm.product = product;
      vm.productType = lodash.find(productTypes, {title: product.product_type});
      logger.info('Activated Admin Products Edit View');
    }
  }
})();
