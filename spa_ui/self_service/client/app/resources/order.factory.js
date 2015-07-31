(function() {
  'use strict';

  angular.module('app.resources')
    .factory('Order', OrderFactory);

  /** @ngInject */
  function OrderFactory($resource) {
    var Order = $resource('/api/v1/orders/:id', {id: '@id'}, {
      items: {
        url: '/api/v1/orders/:id/items',
        method: 'GET',
        isArray: true
      }
    });

    return Order;
  }
})();
