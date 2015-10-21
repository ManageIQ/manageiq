(function() {
  'use strict';

  angular.module('app.config')
    .constant('API_BASE', location.protocol + '//' + location.host)
    .constant('API_LOGIN', '')
    .constant('API_PASSWORD', '');
})();
