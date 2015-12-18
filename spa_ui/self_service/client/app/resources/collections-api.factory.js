(function() {
  'use strict';

  angular.module('app.resources')
    .factory('CollectionsApi', CollectionsApiFactory);

  /** @ngInject */
  function CollectionsApiFactory($http, API_BASE) {
    var service = {
      query: query,
      get: get,
      post: post
    };

    return service;

    function query(collection, options) {
      var url = API_BASE + '/api/' + collection;

      return $http.get(url + buildQuery(options), buildConfig(options))
        .then(handleSuccess);

      function handleSuccess(response) {
        return response.data;
      }
    }

    function get(collection, id, options) {
      var url = API_BASE + '/api/' + collection + '/' + id;

      return $http.get(url + buildQuery(options), buildConfig(options))
        .then(handleSuccess);

      function handleSuccess(response) {
        return response.data;
      }
    }

    function post(collection, id, options, data) {
      var url = API_BASE + '/api/' + collection + '/' + id + buildQuery(options);

      return $http.post(url, data, buildConfig(options))
        .then(handleSuccess);

      function handleSuccess(response) {
        return response.data;
      }
    }

    // Private

    function buildQuery(options) {
      var params = [];
      options = options || {};

      if (options.expand) {
        params.push('expand=' + options.expand);
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

      if (options.sort_by) {
        params.push('sort_by=' + options.sort_by);
      }

      if (options.sort_options) {
        params.push('sort_options=' + options.sort_options);
      }

      if (params.length) {
        return '?' + params.join('&');
      }

      return '';
    }

    function buildConfig(options) {
      var config = {};
      options = options || {};

      if (options._auto_refresh) {
        config.headers = {
          'X-Auth-Skip-Token-Renewal': 'true',
        };
      }

      return config;
    }
  }
})();
