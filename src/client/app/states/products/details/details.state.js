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
      'products.details': {
        url: 'product/:productId',
        templateUrl: 'app/states/products/details/details.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Products Details',
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
  function StateController(logger, product, $stateParams, lodash) {
    var vm = this;

    vm.title = 'Service Details';

    vm.productId = $stateParams.productId;
    vm.product = product;

    vm.activate = activate;
    vm.toAlertType = toAlertType;
    vm.tagList = tagList;

    activate();

    function activate() {
      logger.info('Activated Products Details View');
    }

    function toAlertType(type) {
      switch (type.toLowerCase()) {
        case 'critical':
          return 'danger';
        case 'warning':
          return 'warning';
        case 'ok':
          return 'success';
        default:
          return 'info';
      }
    }

    function tagList(list) {
      return lodash.flatten(list).join(', ');
    }
  }
})();
