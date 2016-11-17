/* global miqHttpInject */

angular.module('alertsCenter')
  .controller('alertsOverviewController', ['$scope', '$http', '$interval', '$window',
    function($scope,  $http, $interval, $window) {
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
        vm.displayFilters = [];
        vm.severityTitles = [__("Information"), __("Warning"), __("Error")];

        // Eventually this should be retrieved from smart tags
        vm.categories = ["Environment"];
        vm.category = vm.categories[0];

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
              id: 'severity',
              title: __('Severity'),
              placeholder: __('Filter by Severity'),
              filterType: 'select',
              filterValues: vm.severityTitles
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

      function filterStringCompare(value1, value2) {
        var match = false;

        if (angular.isString(value1) && angular.isString(value2)) {
          match = value1.toLowerCase().indexOf(value2.toLowerCase()) !== -1;
        }

        return match;
      }

      function matchesFilter(item, filter) {
        var found = false;

        if (filter.id === 'severity') {
          if (filter.value === vm.severityTitles[0]) {
            found = item.info.length > 0;
          }
          else if (filter.value === vm.severityTitles[1]) {
            found = item.warning.length > 0;
          }
          if (filter.value === vm.severityTitles[2]) {
            found = item.danger.length > 0;
          }
        } else if (filter.id === 'name') {
          found = filterStringCompare(item.objectName, filter.value);
        }

        return found;
      }

      function filteredOut(item) {
        var filtered = true;
        if (item.info.length + item.warning.length + item.danger.length > 0) {
          var filter = _.find(vm.filterConfig.appliedFilters, function (filter) {
            if (!matchesFilter(item, filter)) {
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
        var url = "/alerts_list/show?name=" + item.name + "&severity=" + status;
        $window.location.href = url;
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
        var responseData = response;
        var path = '/assets/svg/';
        var suffix = '.svg';

        var filterFound = false;

        // Add each alert in the appropriate group
        vm.alertData.splice(0, vm.alertData.length);
        angular.forEach(responseData.resources, function(item) {
          var prefix = '';
          var objectType = item.type;
          var descriptors = item.type.toLowerCase().split("::");

          item.displayType = responseData.name.toLowerCase();

          if (descriptors.length >= 3) {
            item.displayType = descriptors[1];
            objectType = descriptors[2];
          }
          objectType = objectType.replace(/([a-z\d])([A-Z]+)/g, '$1_$2').replace(/[-\s]+/g, '_').toLowerCase();

          if (item.displayType === 'providers') {
            prefix = 'vendor-';
          } else {
            prefix = 'os-';
          }

          item.objectTypeImg = path + prefix + objectType + suffix;

          if (vm.displayFilters.indexOf(item.displayType) === -1) {
            vm.displayFilters.push(item.displayType);
            if (vm.displayFilter === item.displayType) {
              filterFound = true;
            }
          }

          // categorize the alerts
          item.danger = [];
          item.warning = [];
          item.info = [];
          angular.forEach(item.alert_statuses, function (nextStatus) {
            // Determine the categories for this object
            angular.forEach(vm.categories, function(nextCategory) {
              item[nextCategory] = nextStatus[nextCategory];
            });

            // Add the alerts for this object
            angular.forEach(nextStatus.alerts, function (nextAlert) {
              // Default severity is info if severity is not an expected value
              if (angular.isUndefined(nextAlert.severity)) {
                nextAlert.severity = 'info';
              }
              item[nextAlert.severity].push(nextAlert);
            });
          });
          vm.alertData.push(item);
        });

        // Once we have both providers and hosts from different APIs(?) handle this better
        if (!filterFound) {
          vm.displayFilter = vm.displayFilters[0];
        }

        vm.filterChange();

        vm.loadingDone = true;
      }

      vm.refresh = function() {
        vm.displayFilters.splice(0, vm.displayFilters.length);

        $http.get('/api/providers?expand=resources,alert_statuses').success(processData);
      };

      vm.onHoverAlerts = function(alerts) {
        vm.hoverAlerts = alerts;
      };

      setupInitialValues();
      vm.refresh();

      var promise = $interval(vm.refresh, 1000 * 60 * 3);
      $scope.$on('$destroy', function() {
        $interval.cancel(promise);
      });
    }
  ]
);
