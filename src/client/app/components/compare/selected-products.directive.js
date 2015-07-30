(function() {
  'use strict';

  angular.module('app.components')
    .directive('selectedProducts', SelectedProductsDirective);

  /** @ngInject */
  function SelectedProductsDirective() {
    var directive = {
      restrict: 'AE',
      scope: {},
      link: link,
      templateUrl: 'app/components/compare/selected-products.html',
      controller: SelectedProductsController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function SelectedProductsController(Compare, MAX_COMPARES) {
      var vm = this;

      vm.activate = activate;
      vm.remove = remove;
      vm.showModal = showModal;
      vm.disabled = disabled;

      function activate() {
        buildIndexes(MAX_COMPARES);
        vm.products = Compare.items;
      }

      function remove(product) {
        Compare.remove(product);
      }

      function showModal() {
        Compare.showModal();
      }

      function disabled() {
        return Compare.items.length <= 1;
      }

      // Private

      function buildIndexes(max) {
        vm.indexes = [];

        for (var idx = 0; idx < max; idx++) {
          vm.indexes.push(idx);
        }
      }
    }
  }
})();
