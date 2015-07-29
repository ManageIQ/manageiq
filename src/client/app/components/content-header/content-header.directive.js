(function() {
  'use strict';

  angular.module('app.components')
    .directive('contentHeader', ContentHeaderDirective);

  /** @ngInject */
  function ContentHeaderDirective() {
    var directive = {
      restrict: 'AE',
      scope: {
        short: '=?'
      },
      transclude: true,
      link: link,
      templateUrl: 'app/components/content-header/content-header.html',
      controller: ContentHeaderController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function ContentHeaderController() {
      var vm = this;

      vm.activate = activate;

      function activate() {
        vm.short = angular.isDefined(vm.short) ? vm.short : false;
      }
    }
  }
})();
