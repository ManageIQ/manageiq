(function() {
  'use strict';

  angular.module('mock')
      .run(mock);

  /** @ngInject */
  function mock($httpBackend) {
    $httpBackend.whenGET(/\/api\/v1\/content_pages/).respond(getEmptyResponse);
    $httpBackend.whenGET(/\/api\/v1\/projects/).respond(getEmptyResponse);
    $httpBackend.whenGET(/\/api\/v1\/orders/).respond(getEmptyResponse);
    $httpBackend.whenGET(/\/api\/v1\/services/).respond(getEmptyResponse);

    function getEmptyResponse(method, url, data) {
      return [200, []];
    }
  }
})();
