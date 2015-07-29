(function() {
  'use strict';

  angular.module('app.resources')
    .factory('ServicesProjectCount', ServicesProjectCountFactory);

  /** @ngInject */
  function ServicesProjectCountFactory($resource) {
    var ServicesProjectCount = $resource('/api/v1/services/project_count', {});

    return ServicesProjectCount;
  }
})();
