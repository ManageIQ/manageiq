(function() {
  'use strict';

  angular.module('app.components')
    .directive('detailsTable', DetailsTableDirective);

  /** @ngInject */
  function DetailsTableDirective() {
    var directive = {
      restrict: 'AE',
      transclude: true,
      scope: {
        heading: '@?'
      },
      link: link,
      templateUrl: 'app/components/details-table/details-table.html',
      controller: DetailsTableController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function DetailsTableController() {
      var vm = this;

      vm.activate = activate;

      function activate() {
        vm.heading = angular.isDefined(vm.heading) ? vm.heading : 'Details';
      }
    }
  }
})();
