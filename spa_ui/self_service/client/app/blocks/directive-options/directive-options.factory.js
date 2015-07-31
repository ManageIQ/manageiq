(function() {
  'use strict';

  angular.module('blocks.directive-options')
    .factory('DirectiveOptions', DirectiveOptionsFactory);

  /** @ngInject */
  function DirectiveOptionsFactory($interpolate) {
    var service = {
      load: load
    };

    var converters = {};

    converters[String] = stringConverter;
    converters[Number] = numberConverter;
    converters[Boolean] = booleanConverter;
    converters[RegExp] = regExpConverter;

    return service;

    function load(scope, attrs, options) {
      scope.options = {};

      angular.forEach(options, loadValues);

      function loadValues(value, key) {
        var type = value[0];
        var localDefault = value[1];
        var validator = value[2] || defaultValidator;
        var converter = converters[type];

        setValue(attrs[key] && $interpolate(attrs[key])(scope.$parent));

        function setValue(value) {
          scope.options[key] = value && validator(value) ? converter(value) : localDefault;
        }
      }
    }

    function stringConverter(value) {
      return value;
    }

    function numberConverter(value) {
      return parseInt(value, 10);
    }

    function booleanConverter(value) {
      return 'true' === value.toLowerCase();
    }

    function regExpConverter(value) {
      return new RegExp(value);
    }

    function defaultValidator() {
      return true;
    }
  }
})();
