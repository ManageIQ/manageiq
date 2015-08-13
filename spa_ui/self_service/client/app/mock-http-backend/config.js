(function() {
  'use strict';

  angular.module('mock')
    .run(mock);

  function mock($httpBackend) {
    $httpBackend.whenGET(/^(?!\/api\/).+$/).passThrough();
  }
})();
