(function() {
  'use strict';

  angular.module('app.services')
    .factory('MarketplaceState', MarketplaceStateFactory);

  /** @ngInject */
  function MarketplaceStateFactory() {
    var service = {};   
    
    service.filters = [];

    service.setFilters = function(filterArray) {
      service.filters = filterArray;
    };

    service.getFilters = function() {
      return service.filters;
    };

    return service;
  }
})();
