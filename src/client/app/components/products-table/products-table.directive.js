(function() {
  'use strict';

  angular.module('app.components')
    .directive('productsTable', ProductsTableDirective);

  /** @ngInject */
  function ProductsTableDirective() {
    var directive = {
      restrict: 'AE',
      scope: {
        products: '='
      },
      link: link,
      templateUrl: 'app/components/products-table/products-table.html',
      controller: ProductsTableController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function ProductsTableController() {
      var vm = this;

      vm.activate = activate;

      function activate() {
      }
    }
  }
})();
