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
      'order-history.list': {
        url: '', // No url, this state is the index of order-history
        templateUrl: 'app/states/order-history/list/list.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Order History',
        resolve: {
          orders: resolveOrders
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
  function resolveOrders(Order) {
    return Order.query({'includes[]': ['staff', 'order_items']}).$promise;
  }

  /** @ngInject */
  function StateController($state, logger, orders) {
    var vm = this;

    vm.orders = orders;
    vm.title = 'Order History';
    activate();

    function activate() {
      logger.info('Activated Order History View');
    }
  }
})();
