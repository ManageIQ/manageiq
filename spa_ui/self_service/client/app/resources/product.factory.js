(function() {
  'use strict';

  angular.module('app.resources')
    .factory('Product', ProductFactory);

  /** @ngInject */
  function ProductFactory($resource) {
    var Product = $resource('/api/v1/products/:id', {id: '@id'}, {
      update: {
        method: 'PUT',
        isArray: false
      }
    });

    Product.defaults = {
      name: '',
      description: '',
      product_type: '',
      active: true,
      setup_price: '0.0',
      monthly_price: '0.0',
      hourly_price: '0.0',
      tags: [],
      provisioning_answers: {}
    };

    return Product;
  }
})();
