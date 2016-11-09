/* global miqHttpInject */

angular.module('alertsCenter')
  .controller('alertsStatusController', ['$scope', '$http', '$resource', '$interval', '$window', 'API',
    function($scope,  $http, $resource, $interval, $window, API) {
      var vm = this;

      angular.element(document.querySelector('#center_div')).addClass("miq-body");

      vm.severityTitles = [__("Information"), __("Warning"), __("Error")];

      function setupInitialValues () {
        vm.loadingDone = false;

        // TODO: Get these values from the backend
        vm.categories = ["Environment"];
        vm.category = "Environment";
        vm.groups = [
          {
            title: __("Production"),
            value: 'production',
            open: true,
            items: []
          },
          {
            title: __("Staging"),
            value: 'staging',
            open: true,
            items: []
          },
          {
            title: __("QA"),
            value: 'qa',
            open: true,
            items: []
          }
        ];

        // TODO: Get these values from the backend
        vm.typeFilters = [ "providers", "hosts"];
        vm.typeFilter = "providers";

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
            found = item.alerts_types.info.alerts.length > 0;
          }
          else if (filter.value === vm.severityTitles[1]) {
            found = item.alerts_types.warning.alerts.length > 0;
          }
          if (filter.value === vm.severityTitles[2]) {
            found = item.alerts_types.danger.alerts.length > 0;
          }
        } else if (filter.id === 'name') {
          found = filterStringCompare(item.objectName, filter.value);
        }

        return found;
      }

      function filteredOut(item) {
        var filter = _.find(vm.filterConfig.appliedFilters, function (filter) {
          if (!matchesFilter(item, filter)) {
            return true;
          }
        });
        return filter != undefined;
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
          compValue = item1.alerts_types.danger.alerts.length - item2.alerts_types.danger.alerts.length;
        } else if (vm.toolbarConfig.sortConfig.currentField.id === 'warnings') {
          compValue = item1.alerts_types.warning.alerts.length - item2.alerts_types.warning.alerts.length;
        } else if (vm.toolbarConfig.sortConfig.currentField.id === 'infos') {
          compValue = item1.alerts_types.info.alerts.length - item2.alerts_types.info.alerts.length;
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
        var categoryField = vm.category.toLowerCase();

        angular.forEach(vm.groups, function(group) {
          group.itemsList = [];
          if (angular.isArray(vm.alertData[vm.typeFilter])) {
            var items = vm.alertData[vm.typeFilter];
            angular.forEach(items, function (item) {
              if (item[categoryField] === group.value && !filteredOut(item)) {
                group.itemsList.push(item);
              }
            });
          }
          totalCount += group.itemsList.length;
        });

        vm.toolbarConfig.filterConfig.resultsCount = totalCount;

        /* Make sure sorting is maintained */
        sortChange();
      };

      function updateInfo() {
        // Add any computed fields data and put each alert in the appropriate group
        for (var key in vm.alertData) {
          angular.forEach(vm.alertData[key], function(item) {
            if (key === 'providers') {
              item.objectTypeImg = '/assets/100/vendor-' + item.type + '.png';
            } else {
              item.objectTypeImg = '/assets/100/os-' + item.type + '.png';
            }
          });
        }
      }

      vm.refresh = function() {

        // TODO: Replace mock data with real API call
        var url = '/api/alerts_statuses';
        API.post(url, {"action" : "providers_alerts"}).then(function (response) {
            vm.alertData = response;

        //var alertResource = $resource('/assets/mock-data/alerts/alert-data');
        //alertResource.get(function(resource) {
        //  vm.alertData = resource.data[0];

          var filterFound = false;

          vm.displayFilters = [];
          for (var key in vm.alertData) {
            vm.displayFilters.push(key);
            if (vm.displayFilter === key) {
              filterFound = true;
            }
          }

          if (!filterFound) {
            vm.displayFilter = vm.displayFilters[0];
          }

          updateInfo();
          vm.filterChange();

          vm.loadingDone = true;
        });
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
