(function() {
  'use strict';

  angular.module('app.config')
    .constant('API_BASE', 'http://localhost:3000')
    .constant('API_LOGIN', 'admin')
    .constant('API_PASSWORD', 'smartvm')
    .run(init);

  /** @ngInject */
  function init($rootScope, $http, Session) {
    Session.destroy();
    $rootScope.$watch(tokenWatch, updateToken, true);

    function tokenWatch() {
      return Session.current.token;
    }

    function updateToken() {
      if (Session.current.token) {
        $http.defaults.headers.common['X-Auth-Token'] = Session.current.token;
      } else {
        delete $http.defaults.headers.common['X-Auth-Token'];
      }
    }
  }
})();
