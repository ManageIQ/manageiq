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
      'admin.product-categories.create': {
        url: '/create',
        templateUrl: 'app/states/admin/product-categories/create/create.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Create Product Category'
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
  function StateController(logger, ProductCategory) {
    var vm = this;

    vm.title = 'Create Product Category';

    vm.activate = activate;

    activate();

    function activate() {
      initProductCategory();
      logger.info('Activated Create Product Category View');
    }

    // Private

    function initProductCategory() {
      vm.productCategory = ProductCategory.new();
    }
  }
})();
