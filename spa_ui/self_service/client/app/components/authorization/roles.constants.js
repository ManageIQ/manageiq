(function() {
  'use strict';

  angular.module('app.components')
    .constant('userRoles', {
      all: '*',
      user: 'user',
      admin: 'admin'
    });
})();
