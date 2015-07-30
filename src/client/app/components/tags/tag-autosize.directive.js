(function() {
  'use strict';

  angular.module('app.components')
    .directive('tagAutosize', TagAutosizeDirective);

  /** @ngInject */
  function TagAutosizeDirective() {
    var directive = {
      restrict: 'A',
      require: 'ngModel',
      link: link
    };

    return directive;

    function link(scope, element, attrs, ngModel, transclude) {
      var threshold = 3;
      var span = angular.element('<span class="tag-input"></span>');
      var width = 0;

      span
        .css('display', 'none')
        .css('visibility', 'hidden')
        .css('width', 'auto')
        .css('white-space', 'pre');

      element.parent().append(span);

      ngModel.$parsers.unshift(resize);
      ngModel.$formatters.unshift(resize);

      attrs.$observe('placeholder', updatePlaceholder);

      function resize(originalValue) {
        var value = originalValue;

        if (angular.isString(value) && 0 === value.length) {
          value = attrs.placeholder;
        }

        if (value) {
          span.text(value);
          span.css('display', '');
          width = span.prop('offsetWidth');
          span.css('display', 'none');
        }

        element.css('width', width ? width + threshold + 'px' : '');

        return originalValue;
      }

      function updatePlaceholder(value) {
        if (ngModel.$modelValue) {
          return;
        }
        resize(value);
      }
    }
  }
})();
