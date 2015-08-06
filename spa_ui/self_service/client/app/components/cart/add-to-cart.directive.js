(function() {
  'use strict';

  angular.module('app.components')
    .directive('addToCart', AddToCartDirective);

  /** @ngInject */
  function AddToCartDirective() {
    var directive = {
      restrict: 'A',
      scope: {
        project: '=',
        product: '='
      },
      link: link,
      controller: AddToCartController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      element.click(add);

      vm.activate();

      function add() {
        vm.add();
        scope.$apply();
      }
    }

    /** @ngInject */
    function AddToCartController(CartService, lodash) {
      var vm = this;

      vm.activate = activate;

      vm.add = add;
      vm.title = title;
      vm.quantity = quantity;

      function activate() {
        vm.text = angular.isDefined(vm.text) ? vm.text : 'Add To Cart';
        vm.short = angular.isDefined(vm.short) ? vm.short : false;
      }

      function add() {
        CartService.add(vm.project, vm.product);
      }

      function title() {
        return lodash.trim([vm.text, vm.quantity()].join(' '));
      }

      function quantity() {
        var count = CartService.quantity(vm.project, vm.product);

        return count > 0 ? '(' + count + ')' : '';
      }
    }
  }
})();
