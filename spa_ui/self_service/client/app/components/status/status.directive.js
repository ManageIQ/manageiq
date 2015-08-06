(function() {
  'use strict';

  angular.module('app.components')
    .directive('status', StatusDirective);

  /** @ngInject */
  function StatusDirective() {
    var directive = {
      restrict: 'E',
      transclude: true,
      scope: {
        type: '@?'
      },
      link: link,
      template: '<span class="status" ng-class="\'status--\' + vm.modifier" ng-transclude></span>',
      controller: StatusController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function StatusController(lodash) {
      var vm = this;

      vm.activate = activate;

      function activate() {
        vm.modifier = angular.isDefined(vm.type) ? lodash.trim(vm.type.toLowerCase()) : 'warning';
      }
    }
  }
})();
