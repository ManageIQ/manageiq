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
      'admin.product-categories.edit': {
        url: '/edit/:productCategoryId',
        templateUrl: 'app/states/admin/product-categories/edit/edit.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Edit Product Categories',
        resolve: {
          productCategory: resolveProductCategory
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
  function resolveProductCategory(ProductCategory, $stateParams) {
    return ProductCategory.get({id: $stateParams.productCategoryId}).$promise;
  }

  /** @ngInject */
  function StateController(logger, productCategory) {
    var vm = this;

    vm.title = 'Edit Product Category';
    vm.productCategory = productCategory;

    vm.activate = activate;

    activate();

    function activate() {
      logger.info('Activated Edit Product Category View');
    }
  }
})();
