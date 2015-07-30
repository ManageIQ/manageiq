(function() {
  'use strict';

  angular.module('blocks.bind-attrs')
    .directive('bindAttrs', BindAttrsDirective);

  /** @ngInject */
  function BindAttrsDirective() {
    var directive = {
      restrict: 'A',
      link: link
    };

    return directive;

    function link(scope, element, attrs) {
      scope.$watch(attrs.bindAttrs, watch, true);

      function watch(value) {
        angular.forEach(value, set);
      }

      function set(value, key) {
        attrs.$set(key, value);
      }
    }
  }
})();
