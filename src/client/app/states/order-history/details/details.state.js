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
      'order-history.details': {
        url: '/:id',
        templateUrl: 'app/states/order-history/details/details.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Order History Details',
        resolve: {
          order: resolveOrder,
          orderItems: resolveOrderItems
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
  function resolveOrder($stateParams, Order) {
    return Order.get({
      id: $stateParams.id,
      'includes[]': ['staff']
    }).$promise;
  }

  /** @ngInject */
  function resolveOrderItems($stateParams, Order) {
    return Order.items({
      id: $stateParams.id,
      'includes[]': ['project', 'product']
    }).$promise;
  }

  /** @ngInject */
  function StateController(logger, order, orderItems) {
    var vm = this;

    vm.title = 'Order History Details';
    vm.order = order;
    vm.orderItems = orderItems;

    vm.activate = activate;

    activate();

    function activate() {
      logger.info('Activated Order History Details View');
    }
  }
})();
