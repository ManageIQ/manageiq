(function() {
  'use strict';

  angular.module('app.core', [
    // Angular modules
    'ngAnimate',
    'ngSanitize',
    'ngMessages',

    // Blocks modules
    'blocks.exception',
    'blocks.logger',
    'blocks.router',
    'blocks.multi-transclude',
    'blocks.pub-sub',
    'blocks.bind-attrs',
    'blocks.directive-options',
    'blocks.recursion',

    'app.resources',
    'app.services',

    // Third party modules
    'ui.router'
  ]);
})();
