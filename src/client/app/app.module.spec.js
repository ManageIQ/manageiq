(function() {
  'use strict';

  angular.module('app')
    .run(mock);

  function mock($httpBackend) {
    $httpBackend.whenGET(/.*/).passThrough();
  }
})();
