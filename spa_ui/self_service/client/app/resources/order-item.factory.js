(function() {
  'use strict';

  angular.module('app.resources')
    .factory('OrderItems', OrderItemsFactory);

  /** @ngInject */
  function OrderItemsFactory($resource) {
    var OrderItems = $resource('/api/v1/order_items/:id', {id: '@id'}, {

      startService: {
        method: 'PUT',
        url:  '/api/v1/order_items/:id/start_service'
      },
      stopService: {
        method: 'PUT',
        url: '/api/v1/order_items/:id/stop_service'
      }
    });

    return OrderItems;
  }
})();
