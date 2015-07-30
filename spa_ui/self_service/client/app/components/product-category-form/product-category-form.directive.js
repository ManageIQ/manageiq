(function() {
  'use strict';

  angular.module('app.components')
    .directive('productCategoryForm', ProductCategoryFormDirective);

  /** @ngInject */
  function ProductCategoryFormDirective() {
    var directive = {
      restrict: 'AE',
      scope: {
        heading: '@?',
        productCategory: '='
      },
      link: link,
      templateUrl: 'app/components/product-category-form/product-category-form.html',
      controller: ProductCategoryFormController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function ProductCategoryFormController($state, Tag, TAG_QUERY_LIMIT, Toasts) {
      var vm = this;

      var showValidationMessages = false;
      var home = 'admin.product-categories.list';

      vm.activate = activate;
      vm.queryTags = queryTags;
      vm.backToList = backToList;
      vm.queryTags = queryTags;
      vm.showErrors = showErrors;
      vm.hasErrors = hasErrors;
      vm.onSubmit = onSubmit;

      function activate() {
        vm.heading = vm.heading || 'Add A Product Category';
      }

      function queryTags(query) {
        return Tag.query({q: query, limit: TAG_QUERY_LIMIT}).$promise;
      }

      function backToList() {
        $state.go(home);
      }

      function showErrors() {
        return showValidationMessages;
      }

      function hasErrors(field) {
        if (angular.isUndefined(field)) {
          return showValidationMessages && vm.form.$invalid;
        }

        return showValidationMessages && vm.form[field].$invalid;
      }

      function onSubmit() {
        showValidationMessages = true;
        if (vm.form.$valid) {
          if (vm.productCategory.id) {
            vm.productCategory.$update(saveSuccess, saveFailure);
          } else {
            vm.productCategory.$save(saveSuccess, saveFailure);
          }
        }

        return false;

        function saveSuccess() {
          Toasts.toast(vm.productCategory.name + ' product category has been saved.');
          $state.go(home);
        }

        function saveFailure() {
          Toasts.error('Server returned an error while saving.');
        }
      }
    }
  }
})();
