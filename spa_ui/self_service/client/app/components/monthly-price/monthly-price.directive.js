(function() {
  'use strict';

  angular.module('app.components')
    .directive('computedMonthlyPrice', ComputedMonthlyPriceDirective);

  /** @ngInject */
  function ComputedMonthlyPriceDirective() {
    var directive = {
      restrict: 'AE',
      scope: {
        pricing: '=',
        quantity: '=?'
      },
      link: link,
      template: '<span>{{ vm.computeMonthlyTotal()| currency}}</span>',
      controller: ComputedMonthlyPriceController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function ComputedMonthlyPriceController() {
      var vm = this;

      vm.activate = activate;
      vm.computeMonthlyTotal = computeMonthlyTotal;

      function activate() {
        vm.quantity = vm.quantity || 1;
      }

      function computeMonthlyTotal() {
        return ((parseFloat(vm.pricing.monthly_price)) + ((parseFloat(vm.pricing.hourly_price)) * 750)) * vm.quantity;
      }
    }
  }
})();
