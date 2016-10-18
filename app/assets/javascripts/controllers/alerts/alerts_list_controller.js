/* global miqHttpInject */

angular.module('alertsCenter')
  .controller('alertsListController', ['$scope', '$http', '$resource', '$interval', '$timeout', '$window',
    function($scope,  $http, $resource, $interval, $timeout, $window) {
      var vm = this;
      vm.alertsList = [];

      vm.severities = {
        info :{
          title: __("Information"),
          value: 1,
          severityIconClass: "pficon pficon-info",
          severityClass: "alert-info"
        },
        warning: {
          title: __("Warning"),
          value: 2,
          severityIconClass: "pficon pficon-warning-triangle-o",
          severityClass: "alert-warning"
        },
        error: {
          title: __("Error"),
          value: 3,
          severityIconClass: "pficon pficon-error-circle-o",
          severityClass: "alert-danger"
        }
      };

      vm.updateMenuActionForItemFn = function(action, item) {
        if (action.id === 'assign') {
          action.isVisible = item.assigned === false;
        }
        if (action.id === 'unassign') {
          action.isVisible = item.assigned === true;
        }
      };

      vm.refresh = function() {
        // TODO: Replace mock data with real API call
        var alertResource = $resource('/assets/mock-data/alerts/alert-data');
        alertResource.get(function(resource) {
          vm.alerts = [];
          vm.objectTypes.splice(0, vm.objectTypes.length);
          var newTypes = [];
          var alertData = resource.data[0];

          for (var key in alertData) {
            vm.objectTypes.push(key);
            angular.forEach(alertData[key], function (item) {
              if (newTypes.indexOf(item.type) == -1) {
                newTypes.push(item.type);
              }
              addItemAlerts(item, key);
            });
          }

          newTypes.sort();
          angular.forEach(newTypes, function (type) {
            vm.objectTypes.push(type);
          });

          vm.loadingDone = true;
          filterChange(vm.currentFilters);
        });
      };

      function setupConfig () {
        vm.listConfig = {
          showSelectBox: false,
          selectItems: false
        };

        vm.menuActions = [
          {
            id: 'acknowledge',
            name: __('Acknowledge'),
            actionFn: vm.handleAcknowledge
          },
          {
            id: 'assign',
            name: __('Assign'),
            actionFn: vm.handleAssign
          },
          {
            id: 'unassign',
            name: __('Un-Assign'),
            actionFn: vm.handleUnassign
          },
          {
            id: 'comment',
            name: __('Comment'),
            actionFn: vm.handleComment
          }
        ];

        vm.currentFilters = [];
        vm.objectTypes = [];

        vm.filterConfig = {
          fields: [
            {
              id: 'severity',
              title: __('Severity'),
              placeholder: __('Filter by Severity'),
              filterType: 'select',
              filterValues: getSeverityTitles()
            },
            {
              id: 'name',
              title: __('Object Name'),
              placeholder: __('Filter by Object Name'),
              filterType: 'text'
            },
            {
              id: 'type',
              title: __('Object Type'),
              placeholder: __('Filter by Object Type'),
              filterType: 'select',
              filterValues: vm.objectTypes
            },
            {
              id: 'message',
              title: __('Message Text'),
              placeholder: __('Filter by Message Text'),
              filterType: 'text'
            },
          ],
          resultsCount: vm.alertsList.length,
          appliedFilters: vm.currentFilters,
          onFilterChange: filterChange
        };

        vm.sortConfig = {
          fields: [
            {
              id: 'time',
              title: __('Time'),
              sortType: 'numeric'
            },
            {
              id: 'severity',
              title: __('Severity'),
              sortType: 'numeric'
            },
            {
              id: 'name',
              title: __('Object Name'),
              sortType: 'alpha'
            },
            {
              id: 'type',
              title: __('Object Type'),
              sortType: 'alpha'
            }
          ],
          onSortChange: sortChange,
          isAscending: true
        };

        if (angular.isString($window.location.search)) {
          var filterString = $window.location.search.slice(1);
          var filters = filterString.split('&');
          _.forEach(filters, function(nextFilter) {
            var filter = nextFilter.split('=');
            var filterId = filter[0].replace(/\[\d*\]/, function(v) {
              paramNum = v.slice(1,-1);
              return '';
            });

            // set parameter value (use 'true' if empty)
            var filterValue = angular.isUndefined(filter[1]) ? true : filter[1];
            filterValue = decodeURIComponent(filterValue);

            var filterField = _.find(vm.filterConfig.fields, function(field) {
              return field.id === filterId;
            });
            if (angular.isDefined(filterField)) {
              vm.currentFilters.push({
                id: filterField.id,
                value: filterValue,
                title: filterField.title
              });
            }
          });
        }

        // Default sort descending by severity
        vm.sortConfig.currentField = vm.sortConfig.fields[1];
        vm.sortConfig.isAscending = false;

        vm.toolbarConfig = {
          filterConfig: vm.filterConfig,
          sortConfig: vm.sortConfig
        };
      }

      function filterChange(filters) {
        vm.alertsList = [];
        if (filters && filters.length > 0) {
          angular.forEach(vm.alerts, function(alert) {
            var doNotAdd = _.find(filters, function(filter) {
              if (!matchesFilter(alert, filter)) {
                return true;
              }
            });
            if (!doNotAdd) {
              vm.alertsList.push(alert);
            }
          });
        } else {
          vm.alertsList = vm.alerts;
        }

        vm.toolbarConfig.filterConfig.resultsCount = vm.alertsList.length;

        /* Make sure sorting is maintained */
        sortChange();
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
          found = item.severityInfo.title === filter.value;
        } else if (filter.id === 'message') {
          found = filterStringCompare(item.message, filter.value);
        } else if (filter.id === 'type') {
          found = item.key === filter.value || item.objectType === filter.value;
        } else if (filter.id === 'name') {
          found = filterStringCompare(item.objectName, filter.value);
        }

        return found;
      }

      function sortChange() {
        if (vm.alertsList) {
          vm.alertsList.sort(compareAlerts);
        }
      }

      function compareAlerts(item1, item2) {
        var compValue = 0;
        if (vm.toolbarConfig.sortConfig.currentField.id === 'time') {
          compValue = item1.timestamp - item2.timestamp;
        } else if (vm.toolbarConfig.sortConfig.currentField.id === 'severity') {
          compValue = item1.severityInfo.value - item2.severityInfo.value;
        } else if (vm.toolbarConfig.sortConfig.currentField.id === 'name') {
          compValue = item1.objectName.localeCompare(item2.objectName);
        } else if (vm.toolbarConfig.sortConfig.currentField.id === 'type') {
          compValue = item1.key.localeCompare(item2.key);
          if (compValue === 0) {
            compValue = item1.objectType.localeCompare(item2.objectType);
          }
        }

        if (compValue === 0) {
          compValue = item1.timestamp - item2.timestamp;
        }

        if (!vm.toolbarConfig.sortConfig.isAscending) {
          compValue = compValue * -1;
        }

        return compValue;
      }

      function convertAlert(key, item, alertData, severity, typeImage) {
        var alert = {
          message: alertData.description,
          key: key,
          objectName: item.name,
          objectType: item.type,
          objectTypeImg: typeImage,
          timestamp: alertData.evaluated_on,
          assigned: alertData.asignee_id !== 0,
          severity: severity,
          severityInfo: vm.severities.error
        };

        if (severity == 'danger') {
          alert.severityInfo = vm.severities.error;
        } else if (severity == 'warning') {
          alert.severityInfo = vm.severities.warning;
        } else {
          alert.severityInfo = vm.severities.info;
        }

        return alert;
      }

      function addItemAlerts(item, key) {
        var typeImage = '/assets/100/unknown.png';
        if (key === 'providers') {
          typeImage = '/assets/100/vendor-' + item.type + '.png';
        } else {
          typeImage = '/assets/100/os-' + item.type + '.png';
        }

        angular.forEach(['danger', 'warning', 'info'], function (severity) {
          angular.forEach(item.alerts_types.danger.alerts, function (alert) {
            vm.alerts.push(convertAlert(key, item, alert, severity, typeImage));
          });
        });
      }

      function getSeverityTitles() {
        var titles = [];

        angular.forEach(vm.severities, function(severity) {
          titles.push(severity.title);
        });

        return titles;
      }
      function handleAcknowledge(item) {
      }

      function handleAssign(item) {
      }

      function handleUnassign(item) {
      }

      function handleComment(item) {
      }

      setupConfig();
      vm.refresh();
      var promise = $interval(vm.refresh, 1000 * 60 * 3);

      $scope.$on('$destroy', function() {
        $interval.cancel(promise);
      });

    }
  ]
);
