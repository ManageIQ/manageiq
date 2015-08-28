(function() {
  'use strict';

  angular.module('app.resources')
    .factory('CollectionsApi', CollectionsApiFactory);

  /** @ngInject */
  function CollectionsApiFactory($http, API_BASE) {
    var service = {
      query: query,
      get: get
    };

    return service;

    function query(collection, options) {
      var url = API_BASE + '/api/' + collection;

      return $http.get(url + buildQuery(options)).then(handleSuccess);

      function handleSuccess(response) {
        return response.data;
      }
    }

    function get(collection, id, options) {
      var url = API_BASE + '/api/' + collection + '/' + id;

      return $http.get(url + buildQuery(options)).then(handleSuccess);

      function handleSuccess(response) {
        return response.data;
      }
    }

    // Private

    function buildQuery(options) {
      var params = [];

      options = options || {};

      if (options.expand) {
        params.push('expand=resources');
      }

      if (options.attributes) {
        if (angular.isArray(options.attributes)) {
          options.attributes = options.attributes.join(',');
        }
        params.push('attributes=' + options.attributes);
      }

      if (options.filter) {
        angular.forEach(options.filter, function(filter) {
          params.push('filter[]=' + filter);
        });
      }

      if (0 < params.length) {
        return '?' + params.join('&');
      }

      return '';
    }
  }
})();
