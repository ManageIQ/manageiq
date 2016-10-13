/* global miqHttpInject */

angular.module('alertsCenter')
  .controller('alertsStatusController', ['$scope', '$http', '$interval', '$timeout',
    function($scope,  $http, $interval, $timeout) {
      var vm = this;
      vm.severityTitles = [__("Information"), __("Warning"), __("Error")];

      vm.toggleGroupOpen = function(section) {
        section.open = !section.open;
      };

      vm.filterChange = function() {
        var totalCount = 0;

        angular.forEach(vm.groups, function(group) {
          group.itemsList = [];
          angular.forEach(group.items, function (item) {
            var doNotAdd = !matchesType(item) || _.find(vm.filterConfig.appliedFilters, function (filter) {
                if (!matchesFilter(item, filter)) {
                  return true;
                }
              });
            if (!doNotAdd) {
              group.itemsList.push(item);
            }
          });

          totalCount += group.itemsList.length;
        });

        vm.toolbarConfig.filterConfig.resultsCount = totalCount;

        /* Make sure sorting is maintained */
        sortChange();
      };

      vm.refresh = function() {

        // TODO: Replace mock data with real API call
        $timeout(function () {

          vm.alerts = getMockAlerts();

          updateInfo();
          vm.filterChange();
          vm.loadingDone = true;
        }, 3000);
      };

      function setupInitialValues () {
        vm.loadingDone = false;

        // TODO: Get these values from the backend
        vm.categories = ["Environment"];
        vm.category = "Environment";
        vm.groups = [
          {
            title: __("Production"),
            value: 'production',
            open: false,
            items: []
          },
          {
            title: __("Staging"),
            value: 'staging',
            open: false,
            items: []
          },
          {
            title: __("QA"),
            value: 'qa',
            open: false,
            items: []
          }
        ];

        // TODO: Get these values from the backend
        vm.typeFilters = [ "Providers", "Hosts"];
        vm.typeFilter = "Providers";

        setupConfig();

        // Default sort ascending by error count
        vm.sortConfig.currentField = vm.sortConfig.fields[0];
        vm.sortConfig.isAscending = false;

        // Default to unfiltered
        vm.filterConfig.appliedFilters = [];
      }

      function setupConfig() {
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

      function updateInfo() {
        // Reset the groups
        vm.groups[0].items = [];
        vm.groups[1].items = [];
        vm.groups[2].items = [];

        // Add any computed fields data and put each alert in the appropriate group
        angular.forEach(vm.alerts, function(item) {
          if (item.objectType === 'linux') {
            item.objectTypeImg = '/assets/100/os-linux_generic.png';
          } else if (item.objectType === 'windows') {
            item.objectTypeImg = '/assets/100/os-windows_generic.png';
          } else if (item.objectType === 'esx') {
            item.objectTypeImg = '/assets/100/os-vmware-esx-server.png';
          } else if (item.objectType === 'openshift') {
            item.objectTypeImg = '/assets/100/vendor-openshift.png';
          } else if (item.objectType === 'openstack') {
            item.objectTypeImg = '/assets/100/vendor-openstack_storage.png';
          } else if (item.objectType === 'kubernetes') {
            item.objectTypeImg = '/assets/100/vendor-kubernetes.png';
          } else {
            item.objectTypeImg = '/assets/100/unknown.png';
          }

          if (vm.category === 'Environment') {
            if (item.environment === 'production') {
              vm.groups[0].items.push(item);
            }
            else if (item.environment === 'staging') {
              vm.groups[1].items.push(item);
            }
            else if (item.environment === 'qa') {
              vm.groups[2].items.push(item);
            }
          }
        });
      }

      function matchesType(item) {
        return (vm.typeFilter === "Hosts" && item.displayType === 'host') ||
               (vm.typeFilter === "Providers" && item.displayType === 'provider');
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
            found = item.info > 0;
          }
          else if (filter.value === vm.severityTitles[1]) {
            found = item.warnings > 0;
          }
          if (filter.value === vm.severityTitles[2]) {
            found = item.errors > 0;
          }
        } else if (filter.id === 'name') {
          found = filterStringCompare(item.objectName, filter.value);
        }

        return found;
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
          compValue = item1.errors - item2.errors;
        } else if (vm.toolbarConfig.sortConfig.currentField.id === 'warnings') {
          compValue = item1.warnings - item2.warnings;
        } else if (vm.toolbarConfig.sortConfig.currentField.id === 'infos') {
          compValue = item1.info - item2.info;
        } else if (vm.toolbarConfig.sortConfig.currentField.id === 'object_name') {
          compValue = item1.objectName.localeCompare(item2.objectName);
        } else if (vm.toolbarConfig.sortConfig.currentField.id === 'object_type') {
          compValue = item1.displayType - item2.displayType;
        }

        if (compValue === 0) {
          compValue = item1.objectName.localeCompare(item2.objectName);
        }

        if (!vm.toolbarConfig.sortConfig.isAscending) {
          compValue = compValue * -1;
        }

        return compValue;
      }

      setupInitialValues();
      vm.refresh();

      var promise = $interval(vm.refresh, 1000 * 60 * 3);
      $scope.$on('$destroy', function() {
        $interval.cancel(promise);
      });
    }
  ]
);


function getMockAlerts() {
  return [
    {
      errors: 15,
      warnings: 15,
      info: 15,
      environment: 'production',
      displayType: "host",
      objectName: "Host 1",
      objectType: 'linux'
    },
    {
      errors: 13,
      warnings: 2,
      info: 1,
      environment: 'production',
      displayType: "host",
      objectName: "Host 2",
      objectType: 'windows'
    },
    {
      errors: 2,
      warnings: 8,
      info: 12,
      environment: 'production',
      displayType: "host",
      objectName: "Host 3",
      objectType: 'esx'
    },
    {
      errors: 5,
      warnings: 12,
      info: 2,
      environment: 'production',
      displayType: "host",
      objectName: "Host 4",
      objectType: 'linux'
    },
    {
      errors: 3,
      warnings: 4,
      info: 8,
      environment: 'production',
      displayType: "host",
      objectName: "Host 5",
      objectType: 'linux'
    },
    {
      errors: 11,
      warnings: 3,
      info: 0,
      environment: 'production',
      displayType: "host",
      objectName: "Host 6",
      objectType: 'windows'
    },
    {
      errors: 0,
      warnings: 0,
      info: 5,
      environment: 'production',
      displayType: "host",
      objectName: "Host 7",
      objectType: 'windows'
    },
    {
      errors: 12,
      warnings: 0,
      info: 0,
      environment: 'production',
      displayType: "host",
      objectName: "Host 8",
      objectType: 'esx'
    },
    {
      errors: 2,
      warnings: 1,
      info: 0,
      environment: 'production',
      displayType: "host",
      objectName: "Host 9",
      objectType: 'linux'
    },
    {
      errors: 15,
      warnings: 12,
      info: 1,
      environment: 'production',
      displayType: "host",
      objectName: "Host 10",
      objectType: 'linux'
    },
    {
      errors: 1,
      warnings: 0,
      info: 12,
      environment: 'production',
      displayType: "host",
      objectName: "Host 11",
      objectType: 'esx'
    },
    {
      errors: 15,
      warnings: 15,
      info: 15,
      environment: 'production',
      displayType: "provider",
      objectName: "Provider 1",
      objectType: 'openshift'
    },
    {
      errors: 13,
      warnings: 2,
      info: 1,
      environment: 'production',
      displayType: "provider",
      objectName: "Provider 2",
      objectType: 'openshift'
    },
    {
      errors: 2,
      warnings: 8,
      info: 12,
      environment: 'production',
      displayType: "provider",
      objectName: "Provider 3",
      objectType: 'kubernetes'
    },
    {
      errors: 5,
      warnings: 12,
      info: 2,
      environment: 'production',
      displayType: "provider",
      objectName: "Provider 4",
      objectType: 'openshift'
    },
    {
      errors: 3,
      warnings: 4,
      info: 8,
      environment: 'production',
      displayType: "provider",
      objectName: "Provider 5",
      objectType: 'kubernetes'
    },
    {
      errors: 11,
      warnings: 3,
      info: 0,
      environment: 'production',
      displayType: "provider",
      objectName: "Provider 6",
      objectType: 'openshift'
    },
    {
      errors: 0,
      warnings: 0,
      info: 5,
      environment: 'production',
      displayType: "provider",
      objectName: "Provider 7",
      objectType: 'kubernetes'
    },
    {
      errors: 12,
      warnings: 0,
      info: 0,
      environment: 'production',
      displayType: "provider",
      objectName: "Provider 8",
      objectType: 'openshift'
    },
    {
      errors: 2,
      warnings: 1,
      info: 0,
      environment: 'production',
      displayType: "provider",
      objectName: "Provider 9",
      objectType: 'openshift'
    },
    {
      errors: 15,
      warnings: 12,
      info: 1,
      environment: 'production',
      displayType: "provider",
      objectName: "Provider 10",
      objectType: 'openshift'
    },
    {
      errors: 1,
      warnings: 0,
      info: 12,
      environment: 'production',
      displayType: "provider",
      objectName: "Provider 11",
      objectType: 'kubernetes'
    },
    {
      errors: 3,
      warnings: 4,
      info: 8,
      environment: 'staging',
      displayType: "host",
      objectName: "Host 15",
      objectType: 'linux'
    },
    {
      errors: 11,
      warnings: 3,
      info: 0,
      environment: 'staging',
      displayType: "host",
      objectName: "Host 16",
      objectType: 'windows'
    },
    {
      errors: 2,
      warnings: 1,
      info: 0,
      environment: 'staging',
      displayType: "host",
      objectName: "Host 19",
      objectType: 'linux'
    },
    {
      errors: 15,
      warnings: 12,
      info: 1,
      environment: 'staging',
      displayType: "host",
      objectName: "Host 20",
      objectType: 'esx'
    },
    {
      errors: 1,
      warnings: 0,
      info: 12,
      environment: 'staging',
      displayType: "host",
      objectName: "Host 21",
      objectType: 'windows'
    },
    {
      errors: 5,
      warnings: 12,
      info: 2,
      environment: 'staging',
      displayType: "provider",
      objectName: "Provider 14",
      objectType: 'kubernetes'
    },
    {
      errors: 11,
      warnings: 3,
      info: 0,
      environment: 'staging',
      displayType: "provider",
      objectName: "Provider 16",
      objectType: 'openshift'
    },
    {
      errors: 0,
      warnings: 0,
      info: 5,
      environment: 'staging',
      displayType: "provider",
      objectName: "Provider 17",
      objectType: 'kubernetes'
    },
    {
      errors: 15,
      warnings: 12,
      info: 1,
      environment: 'staging',
      displayType: "provider",
      objectName: "Provider 20",
      objectType: 'openshift'
    },
    {
      errors: 3,
      warnings: 4,
      info: 8,
      environment: 'qa',
      displayType: "host",
      objectName: "Host 25",
      objectType: 'linux'
    },
    {
      errors: 11,
      warnings: 3,
      info: 0,
      environment: 'qa',
      displayType: "host",
      objectName: "Host 26",
      objectType: 'windows'
    },
    {
      errors: 12,
      warnings: 0,
      info: 0,
      environment: 'qa',
      displayType: "host",
      objectName: "Host 28",
      objectType: 'esx'
    },
    {
      errors: 1,
      warnings: 0,
      info: 12,
      environment: 'qa',
      displayType: "host",
      objectName: "Host 31",
      objectType: 'linux'
    },
    {
      errors: 15,
      warnings: 15,
      info: 15,
      environment: 'qa',
      displayType: "provider",
      objectName: "Provider 21",
      objectType: 'openshift'
    },
    {
      errors: 2,
      warnings: 8,
      info: 12,
      environment: 'qa',
      displayType: "provider",
      objectName: "Provider 23",
      objectType: 'kubernetes'
    },
    {
      errors: 0,
      warnings: 0,
      info: 5,
      environment: 'qa',
      displayType: "provider",
      objectName: "Provider 27",
      objectType: 'openshift'
    },
    {
      errors: 12,
      warnings: 0,
      info: 0,
      environment: 'qa',
      displayType: "provider",
      objectName: "Provider 28",
      objectType: 'kubernetes'
    }
  ];

}