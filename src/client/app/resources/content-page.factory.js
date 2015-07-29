(function() {
  'use strict';

  angular.module('app.resources')
    .factory('ContentPage', ContentPagesFactory);

  /** @ngInject */
  function ContentPagesFactory($resource) {
    var ContentPages = $resource('/api/v1/content_pages/:id' , {id: '@id'}, {
      'update': {
        method: 'PUT',
        isArray: false
      }
    });

    return ContentPages;
  }
})();
