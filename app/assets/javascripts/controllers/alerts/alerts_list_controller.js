/* global miqHttpInject */

angular.module('alertsCenter')
  .controller('alertsListController',
              ['$scope', '$interval', '$timeout', '$modal', '$window', '$document', '$http',
    function($scope, $interval, $timeout, $modal, $window, $document, $http) {
      var vm = this;
      var alertsURL = '/api/providers';
      var alertsStatusURL = '/api/alert_statuses';
      var refreshInterval = 1000 * 60 * 3;

      vm.alertsList = [];
      vm.acknowledgedTooltip = __("Acknowledged");

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
        if (action.id === 'unassign') {
          action.isVisible = item.assigned;
        }
        if (action.id === 'acknowledge') {
          action.isVisible = item.assignee_id == vm.currentUser.id && item.acknowledged !== true;
        }
        if (action.id === 'unacknowledge') {
          action.isVisible = item.assignee_id == vm.currentUser.id && item.acknowledged === true;
        }
      };

      function getObjectType(item) {
        var objectType = item.type;
        var descriptors = item.type.split("::");

        if (descriptors.length >= 3) {
          objectType = descriptors[2];
        }

        return objectType;
      }

      function getUserByIdOrUserId(id) {
        var foundUser;
        for (var i = 0; i < vm.existingUsers.length && !foundUser; i++) {
          if (vm.existingUsers[i].id === id || vm.existingUsers[i].userid === id) {
            foundUser = vm.existingUsers[i];
          }
        }

        return foundUser;
      }

      function processData(response) {
        var alertData = response;
        vm.alerts = [];
        vm.objectTypes.splice(0, vm.objectTypes.length);
        var newTypes = [];
        var retrievalTime = (new Date()).getTime();
        var key = alertData.name;

        angular.forEach(alertData.resources, function (item) {
          // Add filter for this object type
          var objectType = getObjectType(item);
          if (newTypes.indexOf(objectType) == -1) {
            newTypes.push(objectType);
          }

          angular.forEach(item.alert_statuses, function (nextStatus) {
            // Add the alerts for this object
            angular.forEach(nextStatus.alerts, function (nextAlert) {
              vm.alerts.push(convertAlert(nextAlert, key, item.name, objectType, retrievalTime));
            });
          });
        });

        newTypes.sort();
        angular.forEach(newTypes, function (type) {
          vm.objectTypes.push(type);
        });

        vm.loadingDone = true;
        filterChange(vm.currentFilters);
      }

      vm.refresh = function() {
        // Get the existing users
        $http.get('/api/users?expand=resources').success(function(response) {
          vm.existingUsers = response.resources;
          vm.existingUsers.sort(function(user1, user2) {
            return user1.name.localeCompare(user2.name);
          });
          vm.currentUser = getUserByIdOrUserId(vm.currentUser.userid);

          // Get the alert data
          $http.get(alertsURL + '?expand=resources,alert_statuses').success(processData);
        });
      };

      function setupConfig () {
        vm.listConfig = {
          showSelectBox: false,
          selectItems: false,
          useExpandingRows: true
        };

        vm.menuActions = [
          {
            id: 'acknowledge',
            name: __('Acknowledge'),
            actionFn: vm.handleMenuAction
          },
          {
            id: 'addcomment',
            name: __('Add Note'),
            actionFn: vm.handleMenuAction
          },
          {
            id: 'assign',
            name: __('Assign'),
            actionFn: vm.handleMenuAction
          },
          {
            id: 'unacknowledge',
            name: __('Unacknowledge'),
            actionFn: vm.handleMenuAction
          },
          {
            id: 'unassign',
            name: __('Unassign'),
            actionFn: vm.handleMenuAction
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
              id: 'nodeName',
              title: __('Host Name'),
              placeholder: __('Filter by Host Name'),
              filterType: 'text'
            },
            {
              id: 'name',
              title: __('Provider Name'),
              placeholder: __('Filter by Provider Name'),
              filterType: 'text'
            },
            {
              id: 'type',
              title: __('Provider Type'),
              placeholder: __('Filter by Provider Type'),
              filterType: 'select',
              filterValues: vm.objectTypes
            },
            {
              id: 'message',
              title: __('Message Text'),
              placeholder: __('Filter by Message Text'),
              filterType: 'text'
            },
            {
              id: 'assignee',
              title: __('Owner'),
              placeholder: __('Filter by Owner'),
              filterType: 'text'
            },
            {
              id: 'acknowledged',
              title: __('Acknowledged'),
              placeholder: __('Filter by Acknowleged'),
              filterType: 'select',
              filterValues: [__('Acknowledged'), __('Unacknowledged')]
            }
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
              id: 'nodeName',
              title: __('Host Name'),
              sortType: 'alpha'
            },
            {
              id: 'name',
              title: __('Provider Name'),
              sortType: 'alpha'
            },
            {
              id: 'type',
              title: __('Provider Type'),
              sortType: 'alpha'
            },
            {
              id: 'assignee',
              title: __('Owner'),
              sortType: 'alpha'
            },
            {
              id: 'acknowledged',
              title: __('Acknowledged'),
              sortType: 'numeric'
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
          angular.forEach(vm.alerts, function(nextAlert) {
            var doNotAdd = _.find(filters, function(filter) {
              if (!matchesFilter(nextAlert, filter)) {
                return true;
              }
            });
            if (!doNotAdd) {
              vm.alertsList.push(nextAlert);
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
          found = item.objectType === filter.value;
        } else if (filter.id === 'nodeName') {
          found = filterStringCompare(item.node_hostname, filter.value);
        } else if (filter.id === 'name') {
          found = filterStringCompare(item.objectName, filter.value);
        } else if (filter.id === 'assignee') {
          found = item.assignee && item.assignee.localeCompare(filter.value);
        } else if (filter.id === 'acknowledged') {
          found = filter.value == __('Acknowledged') ? item.acknowledged : !item.acknowledged;
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
          compValue = item1.evaluated_on - item2.evaluated_on;
        } else if (vm.toolbarConfig.sortConfig.currentField.id === 'severity') {
          compValue = item1.severityInfo.value - item2.severityInfo.value;
        } else if (vm.toolbarConfig.sortConfig.currentField.id === 'nodeName') {
          compValue = item1.node_hostname.localeCompare(item2.node_hostname);
        } else if (vm.toolbarConfig.sortConfig.currentField.id === 'name') {
          compValue = item1.objectName.localeCompare(item2.objectName);
        } else if (vm.toolbarConfig.sortConfig.currentField.id === 'type') {
          compValue = item1.objectType.localeCompare(item2.objectType);
        } else if (vm.toolbarConfig.sortConfig.currentField.id === 'assignee') {
          compValue = item1.assignee.localeCompare(item2.assignee);
        } else if (vm.toolbarConfig.sortConfig.currentField.id === 'acknowledged') {
          compValue = item1.acknowledged ? (item2.acknowledged ? 0 : -1) :  (item2.acknowledged ? 1 : 0);
        }

        if (compValue === 0) {
          compValue = item1.severityInfo.value - item2.severityInfo.value;
          if (compValue === 0) {
            compValue = item1.evaluated_on - item2.evaluated_on;
          }
        }

        if (!vm.toolbarConfig.sortConfig.isAscending) {
          compValue = compValue * -1;
        }

        return compValue;
      }

      function convertApiTime(apiTimestamp) {
        var apiDate = new Date(apiTimestamp);
        return apiDate.getTime();
      }

      function updateAlertStatus(updateAlert) {
        if (updateAlert && updateAlert.states && updateAlert.states.length > 0) {
          var i;
          var ackFound = false;
          var assignFound = false;

          for (i = 0; i < updateAlert.states.length; i++) {
            updateAlert.states[i].created_at = convertApiTime(updateAlert.states[i].created_at);
            updateAlert.states[i].updated_at = convertApiTime(updateAlert.states[i].updated_at);
          }

          // Sort from newest to oldest
          updateAlert.states.sort(function(state1, state2) {
            return state2.updated_at - state1.updated_at;
          });

          // Set the lastUpdate to the time of the newest state change
          updateAlert.lastUpdate = updateAlert.states[0].updated_at;

          // update based on each state
          updateAlert.numComments = 0;
          for (i = 0; i < updateAlert.states.length; i++) {
            // Look for newest acknowledgement change
            if (!ackFound) {
              if (updateAlert.states[i].action === 'acknowledge') {
                updateAlert.acknowledged = true;
                ackFound = true;
              } else if (updateAlert.states[i].action === 'unacknowledge') {
                updateAlert.acknowledged = false;
                ackFound = true;
              }
            }
            // Look for newest assignment change
            if (!assignFound) {
              if (updateAlert.states[i].action === 'assign') {
                var assignee = getUserByIdOrUserId(updateAlert.states[i].assignee_id);
                if (angular.isDefined(assignee)) {
                  updateAlert.assignee = assignee.name;
                } else {
                  updateAlert.assignee = updateAlert.states[i].assignee_name;
                }
                updateAlert.assignee_id = updateAlert.states[i].assignee_id;
                updateAlert.assigned = true;
                assignFound = true;
              } else if (updateAlert.states[i].action === 'unassign') {
                updateAlert.assigned = false;
                updateAlert.assignee = __("Unassigned");
                assignFound = true;
              }
            }
            // Bump the comments count if a comment was made
            if (updateAlert.states[i].comment) {
              updateAlert.numComments++;
            }
          }

          if (updateAlert.numComments === 1) {
            updateAlert.commentsTooltip = sprintf(__("%d Note"), 1);
          } else {
            updateAlert.commentsTooltip = sprintf(__("%d Notes"), updateAlert.numComments);
          }
        }
      }

      function convertAlert(alertData, key, objectName, objectType, retrievalTime) {
        var path = '/assets/svg/';
        var suffix = '.svg';
        var prefix = '';
        var imageName = objectType.replace(/([a-z\d])([A-Z]+)/g, '$1_$2').replace(/[-\s]+/g, '_').toLowerCase();

        if (key === 'providers') {
          prefix = 'vendor-';
        } else {
          prefix = 'os-';
        }

        var typeImage = path + prefix + imageName + suffix;

        var newAlert = {
          id: alertData.id,
          node_hostname: alertData.node_hostname,
          description: alertData.description,
          assigned: false,
          assignee: __("Unassigned"),
          assignee_id: 0,
          acknowledged: false,
          objectName: objectName,
          objectType: objectType,
          objectTypeImg: typeImage,
          evaluated_on: convertApiTime(alertData.evaluated_on),
          severity: alertData.severity,
          states: alertData.states
        };

        if (newAlert.severity == 'danger') {
          newAlert.severityInfo = vm.severities.error;
        } else if (newAlert.severity == 'warning') {
          newAlert.severityInfo = vm.severities.warning;
        } else {
          newAlert.severityInfo = vm.severities.info;
        }

        newAlert.age = moment.duration(retrievalTime - newAlert.evaluated_on).format("dd[d] hh[h] mm[m] ss[s]");
        newAlert.rowClass = "row alert " + newAlert.severityInfo.severityClass;
        newAlert.lastUpdate = newAlert.evaluated_on;
        newAlert.numComments = 0;
        updateAlertStatus(newAlert);

        return newAlert;
      }

      function getSeverityTitles() {
        var titles = [];

        angular.forEach(vm.severities, function(severity) {
          titles.push(severity.title);
        });

        return titles;
      }

      var modalOptions = {
        animation: true,
        backdrop: 'static',
        templateUrl: '/static/edit_alert_dialog.html',
        scope: $scope
      };


      function processState(response) {
        if (response.results && response.results.length > 0) {
          if (angular.isUndefined(vm.editItem.states)) {
            vm.editItem.states = [];
          }
          vm.editItem.states.push(response.results[0]);

          updateAlertStatus(vm.editItem);
          filterChange(vm.currentFilters);
        }
      }

      function doAddState(action) {
        var state = {
          action: action,
          comment: vm.newComment,
          user_id: vm.currentUser.id,
          miq_alert_status_id: vm.editItem.id
        };
        if (action === 'assign') {
          state.assignee_id = vm.owner.id;
        }

        var resource = {
          action: "add",
          resource: state
        };

        var stateURL = alertsStatusURL + '/' + vm.editItem.id + '/alert_status_states';
        $http.post(stateURL, resource).success(processState);
      }

      function doAcknowledge() {
        doAddState('acknowledge');
      }

      function doUnacknowledge() {
        doAddState('unacknowledge');
      }

      function doAssign() {
        if (vm.editItem.assignee_id != vm.owner.id) {
          if (vm.owner) {
            doAddState('assign');

            if (vm.currentAcknowledged !== vm.editItem.acknowledged) {
              vm.currentAcknowledged ? doAcknowledge() : doUnacknowledge();
            }
          } else {
            doUnassign();
          }
        }
      }

      function doUnassign() {
        doAddState('unassign');
      }

      function doAddComment() {
        if (vm.newComment) {
          doAddState("comment");
        }
      }

      function showEditDialog(item, title, showAssign, doneCallback, querySelector) {
        vm.editItem = item;
        vm.editTitle = title;
        vm.showAssign = showAssign;
        vm.owner = undefined;
        vm.currentAcknowledged = vm.editItem.acknowledged;
        for (var i = 0; i < vm.existingUsers.length; i++) {
          if (vm.existingUsers[i].id === item.assignee_id) {
            vm.owner = vm.existingUsers[i];
          }
        }
        vm.newComment = '';
        var modalInstance = $modal.open(modalOptions);
        modalInstance.result.then(doneCallback);

        $timeout(function() {
          var queryResult = $document[0].querySelector(querySelector);
          if (queryResult) {
            queryResult.focus();
          }
        }, 200);
      }

      vm.handleMenuAction = function(action, item) {
        switch (action.id) {
          case 'acknowledge':
            showEditDialog(item, __("Acknowledge Alert"), false, doAcknowledge, '#edit-alert-ok');
            break;
          case 'unacknowledge':
            showEditDialog(item, __("Uncknowledge Alert"), false, doUnacknowledge, '#edit-alert-ok');
            break;
          case 'assign':
            showEditDialog(item, __("Assign Alert"), true, doAssign, '[data-id="assign-select"]');
            break;
          case 'unassign':
            showEditDialog(item, __("Unassign Alert"), false, doUnassign, '#edit-alert-ok-button');
            break;
          case 'addcomment':
            showEditDialog(item, __("Add Note"), false, doAddComment, '#comment-text-area');
            break;
        }
      };

      setupConfig();
      $http.get('/api').success(function(response) {
        vm.currentUser = response.identity;
        vm.refresh();
      });

      if (refreshInterval > 0) {
        var promise = $interval(vm.refresh, refreshInterval);

        $scope.$on('$destroy', function() {
          $interval.cancel(promise);
        });
      }
    }
  ]
);
