/* global miqHttpInject */

miqHttpInject(angular.module('alertsCenter', ['ui.bootstrap', 'patternfly', 'miq.util']))
  .controller('alertsListController', ['$scope', '$http', '$interval', '$timeout',
    function($scope,  $http, $interval, $timeout) {
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
        var url = '/alerts';
//      $http.get(url).success(function(response) {
        $timeout(function() {
          'use strict';

          vm.alerts = [
            {
              severity: 'error',
              message: 'Error contacting host. Check IP Address and username/password settings.',
              objectName: "Host 1",
              objectType: "host",
              timestamp: timeAgo(2),
              assigned: true
            },
            {
              severity: 'warning',
              message: 'Connection time exceeds thresholds.',
              objectName: "Host 2",
              objectType: "host",
              timestamp: timeAgo(0, 12, 3, 20),
              assigned: false

            },
            {
              severity: 'info',
              message: 'Username/passwords setting was changed for Host 1.',
              objectName: "Host 1",
              objectType: "host",
              timestamp: timeAgo(2, 2, 10, 12),
              assigned: false

            },
            {
              severity: 'error',
              message: 'There is a problem here',
              objectName: "Provider 1",
              objectType: "provider",
              timestamp: timeAgo(0, 0, 2, 19),
              assigned: false

            },
            {
              severity: 'info',
              message: 'System reset occurred.',
              objectName: "Provider 2",
              objectType: "provider",
              timestamp: timeAgo(3, 1, 45, 23),
              assigned: false

            },
            {
              severity: 'warning',
              message: 'Something looks strange here.',
              objectName: "test11",
              objectType: "openstack",
              timestamp: timeAgo(0, 0, 2, 13),
              assigned: true

            },
            {
              severity: 'error',
              message: 'Error writing data, no space left on device.',
              objectName: "cfme-3.1",
              objectType: "cloud_volume",
              timestamp: timeAgo(0, 3, 16, 23),
              assigned: false

            }
          ];

          vm.loadingDone = true;
          updateInfo();
          filterChange();
        }, 2000);
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

        vm.objectTypes = [];
        vm.currentFilters = [];

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
              id: 'object_name',
              title: __('Object Name'),
              placeholder: __('Filter by Object Name'),
              filterType: 'text'
            },
            {
              id: 'object_type',
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
        } else if (filter.id === 'object_type') {
          found = item.objectType === filter.value;
        } else if (filter.id === 'object_name') {
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
        } else if (vm.toolbarConfig.sortConfig.currentField.id === 'object_name') {
          compValue = item1.objectName.localeCompare(item2.objectName);
        } else if (vm.toolbarConfig.sortConfig.currentField.id === 'object_type') {
          compValue = item1.objectType - item2.objectType;
        }

        if (compValue === 0) {
          compValue = item1.timestamp - item2.timestamp;
        }

        if (!vm.toolbarConfig.sortConfig.isAscending) {
          compValue = compValue * -1;
        }

        return compValue;
      }

      function timeAgo(days, hours, minutes, seconds) {
        var now = new Date();

        var timeStamp = now.getTime();

        if (angular.isDefined(days)) {
          timeStamp = timeStamp - (days * 24 * 60 * 60 * 1000);
        }
        if (angular.isDefined(hours)) {
          timeStamp = timeStamp - (hours * 60 * 60 * 1000);
        }
        if (angular.isDefined(minutes)) {
          timeStamp = timeStamp - (minutes * 60 * 1000);
        }
        if (angular.isDefined(seconds)) {
          timeStamp = timeStamp - (seconds * 1000);
        }

        return timeStamp;
      }


      function updateInfo() {
        _.forEach(vm.alerts, function(alert) {
          if (alert.objectType === 'host') {
            alert.objectTypeImg = '/assets/100/os-linux_generic.png';
          } else if (alert.objectType === 'provider') {
            alert.objectTypeImg = '/assets/100/vendor-rhevm.png';
          } else if (alert.objectType === 'openstack') {
            alert.objectTypeImg = '/assets/100/vendor-openstack_storage.png';
          } else if (alert.objectType === 'cloud_volume') {
            alert.objectTypeImg = '/assets/100/cloud_volume.png';
          }

          if ((alert.severity == 'error') || (alert.severity == 'danger')) {
            alert.severityInfo = vm.severities.error;
          } else if (alert.severity == 'warning') {
            alert.severityInfo = vm.severities.warning;
          } else {
            alert.severityInfo = vm.severities.info;
          }
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
