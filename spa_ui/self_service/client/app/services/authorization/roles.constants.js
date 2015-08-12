(function() {
  'use strict';

  angular.module('app.services')
    .constant('userRoles', {
      all: '*',
      user: 'user',
      admin: 'admin'
    });
})();
