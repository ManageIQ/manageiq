(function() {
  'use strict';

  angular.module('app.resources')
    .factory('ProductCategory', ProductCategoryFactory);

  /** @ngInject */
  function ProductCategoryFactory($resource) {
    var ProductCategory = $resource('/api/v1/product_categories/:id', {id: '@id'}, {
      update: {
        method: 'PUT',
        isArray: false
      }
    });

    ProductCategory.defaults = {
      name: '',
      description: '',
      tags: []
    };

    ProductCategory.new = newProductCategory;

    function newProductCategory() {
      return new ProductCategory(angular.copy(ProductCategory.defaults));
    }

    return ProductCategory;
  }
})();
