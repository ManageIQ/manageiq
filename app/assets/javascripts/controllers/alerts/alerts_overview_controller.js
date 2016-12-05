/* global miqHttpInject */

angular.module('alertsCenter').controller('alertsOverviewController', ['$scope', '$window', 'alertsCenterService',
  function($scope,  $window, alertsCenterService) {
    var vm = this;
    vm.alertData = [];

    function setupInitialValues () {
      vm.loadingDone = false;

      angular.element(document.querySelector('#center_div')).addClass("miq-body");

      setupConfig();

      // Default sort ascending by error count
      vm.sortConfig.currentField = vm.sortConfig.fields[0];
      vm.sortConfig.isAscending = false;

      // Default to unfiltered
      vm.filterConfig.appliedFilters = [];
    }

    function setupConfig() {
      vm.severityTitles = [__("Information"), __("Warning"), __("Error")];

      vm.category = alertsCenterService.categories[0];

      vm.groups = [
        {
          value: '',
          title: __("Ungrouped"),
          itemsList: [],
          open: true
        }
      ];

      vm.cardsConfig = {
        selectItems: false,
        multiSelect: false,
        dblClick: false,
        selectionMatchProp: 'name',
        showSelectBox: false
      };

      vm.filterConfig = {
        fields: [
          {
            id: 'severityCount',
            title: __('Severity'),
            placeholder: __('Filter by Severity'),
            filterType: 'select',
            filterValues: alertsCenterService.severityTitles
          },
          {
            id: 'name',
            title: __('Name'),
            placeholder: __('Filter by Name'),
            filterType: 'text'
          }
        ],
        resultsCount: 0,
        appliedFilters: [],
        onFilterChange: vm.filterChange
      };

      vm.sortConfig = {
        fields: [
          {
            id: 'errors',
            title: __('Error Count'),
            sortType: 'numeric'
          },
          {
            id: 'warnings',
            title: __('Warning Count'),
            sortType: 'numeric'
          },
          {
            id: 'infos',
            title: __('Information Count'),
            sortType: 'numeric'
          },
          {
            id: 'object_name',
            title: __('Object Name'),
            sortType: 'alpha'
          },
          {
            id: 'object_type',
            title: __('Object Type'),
            sortType: 'alpha'
          }
        ],
        onSortChange: sortChange,
        isAscending: true
      };

      vm.toolbarConfig = {
        filterConfig: vm.filterConfig,
        sortConfig: vm.sortConfig,
        actionsConfig: {
          actionsInclude: true
        }
      };
    }

    function filteredOut(item) {
      var filtered = true;
      if (item.info.length + item.warning.length + item.danger.length > 0) {
        var filter = _.find(vm.filterConfig.appliedFilters, function (filter) {
          if (!alertsCenterService.matchesFilter(item, filter)) {
            return true;
          }
        });
        filtered = filter != undefined;
      }
      return filtered;
    }

    function sortChange() {
      angular.forEach(vm.groups, function(group) {
        if (group.itemsList) {
          group.itemsList.sort(compareItems);
        }
      });
    }

    function compareItems(item1, item2) {
      var compValue = 0;
      if (vm.toolbarConfig.sortConfig.currentField.id === 'errors') {
        compValue = item1.danger.length - item2.danger.length;
      } else if (vm.toolbarConfig.sortConfig.currentField.id === 'warnings') {
        compValue = item1.warning.length - item2.warning.length;
      } else if (vm.toolbarConfig.sortConfig.currentField.id === 'infos') {
        compValue = item1.info.length - item2.info.length;
      } else if (vm.toolbarConfig.sortConfig.currentField.id === 'object_name') {
        compValue = item1.name.localeCompare(item2.name);
      } else if (vm.toolbarConfig.sortConfig.currentField.id === 'object_type') {
        compValue = item1.type.localeCompare(item2.type);
      }

      if (compValue === 0) {
        compValue = item1.name.localeCompare(item2.name);
      }

      if (!vm.toolbarConfig.sortConfig.isAscending) {
        compValue = compValue * -1;
      }

      return compValue;
    }

    vm.toggleGroupOpen = function(section) {
      section.open = !section.open;
    };

    vm.showGroupAlerts = function(item, status) {
      $window.location.href = "/alerts_list/show?name=" + item.name + "&severity=" + status;
    };

    vm.filterChange = function() {
      var totalCount = 0;

      // Clear the existing groups' items
      angular.forEach(vm.groups, function(group) {
        group.itemsList = [];
        group.hasItems = false;
      });

      // Add items to the groups
      angular.forEach(vm.alertData, function (item) {
        if (item.displayType === vm.displayFilter) {
          var group = addGroup(item[vm.category]);
          if (!filteredOut(item)) {
            totalCount++;
            group.itemsList.push(item);
          }
        }
      });

      // Sort the groups
      vm.groups.sort(function(group1, group2) {
        if (!group1.value) {
          return -1;
        } else if (!group2.value) {
          return -1;
        }
        else {
          return group1.value.localeCompare(group2.value);
        }
      });

      vm.toolbarConfig.filterConfig.resultsCount = totalCount;

      /* Make sure sorting is maintained */
      sortChange();
    };

    function addGroup(category) {
      var foundGroup;
      var groupCategory = category || __('Not Grouped');

      angular.forEach(vm.groups, function(nextGroup) {
        if (nextGroup.value === groupCategory) {
          foundGroup = nextGroup;
        }
      });

      if (!foundGroup) {
        foundGroup = {value: groupCategory, title: groupCategory, itemsList: [], open: true};
        vm.groups.push(foundGroup);
      }

      foundGroup.hasItems = true;

      return foundGroup;
    }

    function processData(response) {
      vm.alertData = alertsCenterService.convertToAlertsOverview(response);

      // Once we have both providers and hosts from different APIs(?) handle this better
      if (alertsCenterService.displayFilters.indexOf(vm.displayFilter) === -1) {
        vm.displayFilter = alertsCenterService.displayFilters[0];
      }

      vm.displayFilters = alertsCenterService.displayFilters;
      vm.categories = alertsCenterService.categories;

      vm.filterChange();
      vm.loadingDone = true;
    }

    vm.onHoverAlerts = function(alerts) {
      vm.hoverAlerts = alerts;
    };

    setupInitialValues();

    alertsCenterService.registerObserverCallback(vm.filterChange);
    alertsCenterService.initialize(processData);
  }
]);
