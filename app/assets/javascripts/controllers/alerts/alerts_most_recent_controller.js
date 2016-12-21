/* global miqHttpInject */

angular.module('alertsCenter').controller('alertsMostRecentController', ['$scope', '$window', 'alertsCenterService',
  function($scope, $window, alertsCenterService) {
    var vm = this;

    vm.alertsList = [];

    function processData(response) {
      vm.alerts = alertsCenterService.convertToAlertsList(response);
      vm.loadingDone = true;
      vm.filterChange();
    }

    function setupConfig () {
      vm.acknowledgedTooltip = __("Acknowledged");

      vm.showCount = 25;
      vm.showCounts = [25, 50, 100];

      vm.severities = alertsCenterService.severities;

      vm.listConfig = {
        showSelectBox: false,
        selectItems: false,
        useExpandingRows: true
      };

      vm.menuActions = alertsCenterService.menuActions;
      vm.updateMenuActionForItemFn = alertsCenterService.updateMenuActionForItemFn;

      vm.objectTypes = [];
      vm.currentFilters = alertsCenterService.getFiltersFromLocation($window.location.search,
                                                                     alertsCenterService.alertListSortFields);

      vm.filterConfig = {
        fields: alertsCenterService.alertListFilterFields,
        resultsCount: vm.alertsList.length,
        appliedFilters: vm.currentFilters,
        onFilterChange: vm.filterChange
      };


      vm.sortConfig = {
        fields: alertsCenterService.alertListSortFields,
        onSortChange: sortChange,
        isAscending: true
      };

      // Default sort descending by severity
      vm.sortConfig.currentField = vm.sortConfig.fields[1];
      vm.sortConfig.isAscending = false;

      vm.toolbarConfig = {
        filterConfig: vm.filterConfig,
        sortConfig: vm.sortConfig,
        actionsConfig: {
          actionsInclude: true
        }
      };
    }

    vm.filterChange = function() {
      vm.alertsList = [];

      // Sort by update time descending
      vm.alerts.sort(function(alert1, alert2) {
        return (alert2.evaluated_on - alert1.evaluated_on);
      });


      // Keep only the most recent
      var alerts = vm.alerts.slice(0, vm.showCount);

      vm.alertsList = alertsCenterService.filterAlerts(alerts, vm.filterConfig.appliedFilters);

      vm.toolbarConfig.filterConfig.resultsCount = vm.alertsList.length;

      /* Make sure sorting is maintained */
      sortChange();
    };

    function sortChange() {
      if (vm.alertsList) {
        vm.alertsList.sort(function(item1, item2) {
          return alertsCenterService.compareAlerts(item1,
                                                   item2,
                                                   vm.toolbarConfig.sortConfig.currentField.id,
                                                   vm.toolbarConfig.sortConfig.isAscending);
        });
      }
    }

    setupConfig();

    alertsCenterService.registerObserverCallback(vm.filterChange);
    alertsCenterService.initialize(processData);
  }
]);
