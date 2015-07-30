(function() {
  'use strict';

  angular.module('app.components')
    .directive('navCart', NavCartDirective);

  /** @ngInject */
  function NavCartDirective() {
    var directive = {
      restrict: 'AE',
      scope: {},
      link: link,
      templateUrl: 'app/components/cart/nav-cart.html',
      controller: NavCartController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function NavCartController(CartService) {
      var vm = this;

      vm.activate = activate;
      vm.itemCount = itemCount;
      vm.showModal = showModal;

      function activate() {
      }

      function showModal() {
        CartService.showModal();
      }

      function itemCount() {
        return CartService.itemCount;
      }
    }
  }
})();
