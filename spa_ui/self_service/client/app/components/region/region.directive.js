(function() {
  'use strict';

  angular.module('app.components')
    .directive('region', RegionDirective);

  /** @ngInject */
  function RegionDirective() {
    var directive = {
      restrict: 'AE',
      transclude: true,
      scope: {
        heading: '@',
        collapsed: '=?'
      },
      link: link,
      templateUrl: 'app/components/region/region.html',
      controller: RegionController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function RegionController() {
      var vm = this;

      vm.activate = activate;

      function activate() {
        vm.collapsed = angular.isDefined(vm.collapsed) ? vm.collapsed : false;
      }
    }
  }
})();
