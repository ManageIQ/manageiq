(function() {
  'use strict';

  angular.module('app.components')
    .directive('tagMatch', TagMatchDirective);

  /** @ngInject */
  function TagMatchDirective(logger) {
    var directive = {
      restrict: 'AE',
      require: '^tagAutocomplete',
      scope: {
        tag: '=',
        selected: '='
      },
      link: link,
      templateUrl: 'app/components/tags/tag-match.html',
      controller: TagMatchController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, tagAutocomplete, transclude) {
      var vm = scope.vm;

      vm.activate();
    }

    /** @ngInject */
    function TagMatchController() {
      var vm = this;

      vm.activate = activate;

      function activate() {
      }
    }
  }
})();
