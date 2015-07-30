(function() {
  'use strict';

  angular.module('app.components')
    .directive('productFormField', ProductFormFieldDirective);

  /** @ngInject */
  function ProductFormFieldDirective() {
    var directive = {
      restrict: 'AE',
      require: '^productForm',
      link: link
    };

    return directive;

    function link(scope, element, attrs, productForm, transclude) {
      scope.hasErrors = hasErrors;

      function hasErrors(field) {
        return productForm.hasErrors(field);
      }
    }
  }
})();
