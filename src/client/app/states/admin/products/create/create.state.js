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
      'admin.products.create': {
        url: '/create',
        templateUrl: 'app/states/admin/products/create/create.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Admin Products Create',
        params: {
          productType: null
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
  function StateController($stateParams, Product, productTypes) {
    var vm = this;

    vm.title = 'Admin Products Create';
    vm.activate = activate;

    activate();

    function activate() {
      vm.productType = null !== $stateParams.productType ? $stateParams.productType : productTypes[0];
      initProduct();
    }

    // Private

    function initProduct() {
      vm.product = angular.extend(new Product(), Product.defaults);
      vm.product.product_type = vm.productType.title;

      angular.forEach(vm.productType.properties, initProperty);

      function initProperty(property, key) {
        vm.product.provisioning_answers[key] = angular.isDefined(property.default) ? property.default : null;
      }
    }
  }
})();
