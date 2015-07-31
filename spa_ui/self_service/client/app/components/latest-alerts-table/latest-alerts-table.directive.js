(function() {
  'use strict';

  angular.module('app.components')
    .directive('latestAlertsTable', LatestAlertsTableDirective);

  /** @ngInject */
  function LatestAlertsTableDirective() {
    var directive = {
      restrict: 'AE',
      scope: {
        alerts: '='
      },
      link: link,
      templateUrl: 'app/components/latest-alerts-table/latest-alerts-table.html',
      controller: LatestAlertsTableController,
      controllerAs: 'vm',
      bindToController: true
    };

    return directive;

    function link(scope, element, attrs, vm, transclude) {
      vm.activate();
    }

    /** @ngInject */
    function LatestAlertsTableController(lodash, Alert, Toasts) {
      var vm = this;

      vm.activate = activate;
      vm.deleteAlert = deleteAlert;

      activate();

      function activate() {
      }

      function deleteAlert(alert) {
        // TODO: FIGURE OUT THE RIGHT WAY TO DO THIS
        // alert.$delete(deleteSuccess, deleteFailure) returns method not found error
        var deletedAlert = Alert.delete({id: alert.id}).$promise;
        lodash.remove(vm.alerts, {id: alert.id});
        Toasts.toast('Alert deleted.');

        function deleteSuccess() {
          lodash.remove(vm.alerts, {id: alert.id});
          Toasts.toast('Alert deleted.');
        }

        function deleteFailure() {
          Toasts.error('Server returned an error while deleting.');
        }
      }
    }
  }
})();
