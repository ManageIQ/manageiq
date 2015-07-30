(function() {
  'use strict';

  angular.module('app.components')
    .directive('orderItemsTable', OrderItemsTableDirective);

  /** @ngInject */
  function OrderItemsTableDirective() {
    var directive = {
      restrict: 'AE',
      scope: {
        orderItems: '='
      },
      link: link,
      templateUrl: 'app/components/order-items-table/order-items-table.html',
      controller: OrderItemsTableController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function OrderItemsTableController() {
      var vm = this;

      vm.activate = activate;

      function activate() {
      }
    }
  }
})();
