(function() {
  'use strict';

  angular.module('app.components')
    .directive('productCategoriesTable', ProductCategoriesTableDirective);

  /** @ngInject */
  function ProductCategoriesTableDirective() {
    var directive = {
      restrict: 'AE',
      scope: {
        productCategories: '='
      },
      link: link,
      templateUrl: 'app/components/product-categories-table/product-categories-table.html',
      controller: ProductCategoriesTableController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function ProductCategoriesTableController(Toasts) {
      var vm = this;

      vm.activate = activate;
      vm.deleteCategory = deleteCategory;

      function activate() {
      }

      function deleteCategory(index) {
        var category = vm.productCategories[index];

        category.$delete(deleteSuccess, deleteFailure);

        function deleteSuccess() {
          vm.questions.splice(index, 1);
          Toasts.toast('Product Category deleted.');
        }

        function deleteFailure() {
          Toasts.error('Server returned an error while deleting.');
        }
      }
    }
  }
})();
