
(function() {
  'use strict';

  angular.module('app.services')
    .factory('ServicesState', ServicesStateFactory);

  /** @ngInject */
  function ServicesStateFactory() {
    var service = {};   

    service.sort = {
      isAscending: true,
      currentField: { id: 'name', title: __('Name'), sortType: 'alpha' }
    };
    
    service.filters = [];

    service.setSort = function(currentField, isAscending) {
      service.sort.isAscending = isAscending;
      service.sort.currentField = currentField;
    };

    service.getSort = function() {
      return service.sort;
    };

    service.setFilters = function(filterArray) {
      service.filters = filterArray;
    };

    service.getFilters = function() {
      return service.filters;
    };

    return service;
  }
})();
