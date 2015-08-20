(function() {
  'use strict';

  angular.module('app.config')
    .constant('API_BASE', 'http://localhost:3000')
    .constant('API_LOGIN', 'admin')
    .constant('API_PASSWORD', 'smartvm');
})();
