(function() {
  'use strict';

  angular.module('app.components')
    .directive('ordersTable', OrdersTableDirective);

  /** @ngInject */
  function OrdersTableDirective() {
    var directive = {
      restrict: 'AE',
      scope: {
        orders: '='
      },
      link: link,
      templateUrl: 'app/components/orders-table/orders-table.html',
      controller: OrdersTableController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function OrdersTableController() {
      var vm = this;

      vm.activate = activate;

      function activate() {
      }
    }
  }
})();
