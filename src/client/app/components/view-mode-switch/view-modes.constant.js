(function() {
  'use strict';

  var VIEW_MODES = {
    list: 'list',
    grid: 'grid'
  };

  angular.module('app.components')
    .constant('VIEW_MODES', VIEW_MODES);
})();
