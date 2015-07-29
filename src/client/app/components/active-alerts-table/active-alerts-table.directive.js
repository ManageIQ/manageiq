(function() {
  'use strict';

  angular.module('app.components')
    .directive('activeAlertsTable', ActiveAlertsTableDirective);

  /** @ngInject */
  function ActiveAlertsTableDirective() {
    var directive = {
      restrict: 'AE',
      scope: {
        alerts: '='
      },
      link: link,
      templateUrl: 'app/components/active-alerts-table/active-alerts-table.html',
      controller: ActiveAlertsTableController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function ActiveAlertsTableController() {
      var vm = this;

      vm.activate = activate;

      function activate() {
      }
    }
  }
})();
