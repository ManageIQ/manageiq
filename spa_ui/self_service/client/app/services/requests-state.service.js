(function() {
  'use strict';

  angular.module('app.services')
    .factory('RequestsState', RequestsStateFactory);

  /** @ngInject */
  function RequestsStateFactory() {
    var service = {};   

    service.sort = {
      isAscending: false,
      currentField: { id: 'requested', title: 'Request Date', sortType: 'numeric' }
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
