angular.module('alertsCenter').service('alertsCenterService', alertsCenterService);

alertsCenterService.$inject = ['$http', '$timeout', '$interval', '$document', '$modal'];

function alertsCenterService($http, $timeout, $interval, $document, $modal) {
  var _this = this;
  var alertsURL = '/api/providers';
  var alertsStatusURL = '/api/alert_statuses';
  var observerCallbacks = [];
  var refreshInterval = 1000 * 60 * 3;

  var notifyObservers = function(){
    angular.forEach(observerCallbacks, function(callback){
      callback();
    });
  };

  this.registerObserverCallback = function(callback){
    observerCallbacks.push(callback);
  };

  this.unregisterObserverCallback = function(callback){
    var index = observerCallbacks.indexOf(callback);
    if (index > -1) {
      observerCallbacks.splice(index, 1);
    }
  };

  _this.objectTypes = [];

  _this.displayFilters = [];

  // Eventually this should be retrieved from smart tags
  _this.categories = ["Environment"];

  _this.severities = {
    info: {
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

  function getSeverityTitles () {
    var titles = [];

    angular.forEach(_this.severities, function (severity) {
      titles.push(severity.title);
    });

    return titles;
  }

  _this.severityTitles = getSeverityTitles();

  _this.alertListFilterFields = [
    {
      id: 'severity',
      title: __('Severity'),
      placeholder: __('Filter by Severity'),
      filterType: 'select',
      filterValues: _this.severityTitles
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
      filterValues: _this.objectTypes
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
  ];

  _this.getFiltersFromLocation = function (searchString, fields) {
    var currentFilters = [];

    if (angular.isString(searchString)) {
      var filterString = searchString.slice(1);
      var filters = filterString.split('&');
      _.forEach(filters, function (nextFilter) {
        var filter = nextFilter.split('=');
        var filterId = filter[0].replace(/\[\d*\]/, function (v) {
          v.slice(1, -1);
          return '';
        });

        // set parameter value (use 'true' if empty)
        var filterValue = angular.isUndefined(filter[1]) ? true : filter[1];
        filterValue = decodeURIComponent(filterValue);

        var filterField = _.find(fields, function (field) {
          return field.id === filterId;
        });
        if (angular.isDefined(filterField)) {
          currentFilters.push({
            id: filterField.id,
            value: filterValue,
            title: filterField.title
          });
        }
      });
    }

    return currentFilters;
  };

  function filterStringCompare (value1, value2) {
    var match = false;

    if (angular.isString(value1) && angular.isString(value2)) {
      match = value1.toLowerCase().indexOf(value2.toLowerCase()) !== -1;
    }

    return match;
  }

  _this.matchesFilter = function (item, filter) {
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
    } else if (filter.id === 'severityCount') {
      if (filter.value === _this.severityTitles[0]) {
        found = item.info.length > 0;
      } else if (filter.value === _this.severityTitles[1]) {
        found = item.warning.length > 0;
      } else if (filter.value === _this.severityTitles[2]) {
        found = item.danger.length > 0;
      }
    }

    return found;
  };

  _this.filterAlerts = function (alertsList, filters) {
    var filteredAlerts = [];

    angular.forEach(alertsList, function (nextAlert) {
      var doNotAdd = false;
      if (filters && filters.length > 0) {
        doNotAdd = _.find(filters, function (filter) {
          if (!_this.matchesFilter(nextAlert, filter)) {
            return true;
          }
        });
      }
      if (!doNotAdd) {
        filteredAlerts.push(nextAlert);
      }
    });

    return (filteredAlerts)
  };

  _this.compareAlerts = function (item1, item2, sortId, isAscending) {
    var compValue = 0;
    if (sortId === 'time') {
      compValue = item1.evaluated_on - item2.evaluated_on;
    } else if (sortId === 'severity') {
      compValue = item1.severityInfo.value - item2.severityInfo.value;
    } else if (sortId === 'nodeName') {
      compValue = item1.node_hostname.localeCompare(item2.node_hostname);
    } else if (sortId === 'name') {
      compValue = item1.objectName.localeCompare(item2.objectName);
    } else if (sortId === 'type') {
      compValue = item1.objectType.localeCompare(item2.objectType);
    } else if (sortId === 'assignee') {
      compValue = item1.assignee.localeCompare(item2.assignee);
    } else if (sortId === 'acknowledged') {
      compValue = item1.acknowledged ? (item2.acknowledged ? 0 : -1) : (item2.acknowledged ? 1 : 0);
    }

    if (compValue === 0) {
      compValue = item1.severityInfo.value - item2.severityInfo.value;
      if (compValue === 0) {
        compValue = item1.evaluated_on - item2.evaluated_on;
      }
    }

    if (!isAscending) {
      compValue = compValue * -1;
    }

    return compValue;
  };

  _this.alertListSortFields = [
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
  ];

  _this.menuActions = [
    {
      id: 'acknowledge',
      name: __('Acknowledge'),
      actionFn: handleMenuAction
    },
    {
      id: 'addcomment',
      name: __('Add Note'),
      actionFn: handleMenuAction
    },
    {
      id: 'assign',
      name: __('Assign'),
      actionFn: handleMenuAction
    },
    {
      id: 'unacknowledge',
      name: __('Unacknowledge'),
      actionFn: handleMenuAction
    },
    {
      id: 'unassign',
      name: __('Unassign'),
      actionFn: handleMenuAction
    }
  ];

  _this.updateMenuActionForItemFn = function(action, item) {
    if (action.id === 'unassign') {
      action.isVisible = item.assigned;
    }
    if (action.id === 'acknowledge') {
      action.isVisible = item.assignee_id == _this.currentUser.id && item.acknowledged !== true;
    }
    if (action.id === 'unacknowledge') {
      action.isVisible = item.assignee_id == _this.currentUser.id && item.acknowledged === true;
    }
  };

  _this.getUserByIdOrUserId = function (id) {
    var foundUser;
    for (var i = 0; i < _this.existingUsers.length && !foundUser; i++) {
      if (_this.existingUsers[i].id === id || _this.existingUsers[i].userid === id) {
        foundUser = _this.existingUsers[i];
      }
    }

    return foundUser;
  };


  _this.refresh = function (onRefreshCB) {
    // Get the existing users
    $http.get('/api/users?expand=resources').success(function (response) {
      _this.existingUsers = response.resources;
      _this.existingUsers.sort(function (user1, user2) {
        return user1.name.localeCompare(user2.name);
      });
      _this.currentUser = _this.getUserByIdOrUserId(_this.currentUser.userid);
      // Get the alert data
      $http.get(alertsURL + '?expand=resources,alert_statuses').success(onRefreshCB);
    });
  };

  _this.initialize = function (onRefreshCB) {
    $http.get('/api').success(function (response) {
      _this.currentUser = response.identity;
      _this.refresh(onRefreshCB);

      if (refreshInterval > 0) {
        $interval(_this.refresh, refreshInterval);
      }
    });
  };

  function getObjectType (item) {
    var objectType = item.type;
    var descriptors = item.type.split("::");

    if (descriptors.length >= 3) {
      objectType = descriptors[2];
    }

    return objectType;
  }

  function convertApiTime (apiTimestamp) {
    var apiDate = new Date(apiTimestamp);
    return apiDate.getTime();
  }

  function updateAlertStatus (updateAlert) {
    if (updateAlert && updateAlert.states && updateAlert.states.length > 0) {
      var i;
      var ackFound = false;
      var assignFound = false;

      for (i = 0; i < updateAlert.states.length; i++) {
        updateAlert.states[i].created_at = convertApiTime(updateAlert.states[i].created_at);
        updateAlert.states[i].updated_at = convertApiTime(updateAlert.states[i].updated_at);
      }

      // Sort from newest to oldest
      updateAlert.states.sort(function (state1, state2) {
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
            var assignee = _this.getUserByIdOrUserId(updateAlert.states[i].assignee_id);
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

  function convertAlert (alertData, key, objectName, objectType, retrievalTime) {
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
      newAlert.severityInfo = _this.severities.error;
    } else if (newAlert.severity == 'warning') {
      newAlert.severityInfo = _this.severities.warning;
    } else {
      newAlert.severityInfo = _this.severities.info;
    }

    newAlert.age = moment.duration(retrievalTime - newAlert.evaluated_on).format("dd[d] hh[h] mm[m] ss[s]");
    newAlert.rowClass = "row alert " + newAlert.severityInfo.severityClass;
    newAlert.lastUpdate = newAlert.evaluated_on;
    newAlert.numComments = 0;
    updateAlertStatus(newAlert);

    return newAlert;
  }

  _this.convertToAlertsList = function (response) {
    var alertData = response;
    var alerts = [];
    _this.objectTypes.splice(0, _this.objectTypes.length);
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
          alerts.push(convertAlert(nextAlert, key, item.name, objectType, retrievalTime));
        });
      });
    });

    newTypes.sort();
    angular.forEach(newTypes, function (type) {
      _this.objectTypes.push(type);
    });

    return alerts;
  };

  _this.convertToAlertsOverview = function(response) {
    var responseData = response;
    var alertData = [];
    var path = '/assets/svg/';
    var suffix = '.svg';

    // Add each alert in the appropriate group
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

      item.objectName = item.name;
      item.objectTypeImg = path + prefix + objectType + suffix;

      if (_this.displayFilters.indexOf(item.displayType) === -1) {
        _this.displayFilters.push(item.displayType);
      }

      // categorize the alerts
      item.danger = [];
      item.warning = [];
      item.info = [];
      angular.forEach(item.alert_statuses, function (nextStatus) {
        // Determine the categories for this object
        angular.forEach(_this.categories, function(nextCategory) {
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

      alertData.push(item);
    });

    return alertData;
  };

  function processState (response) {
    if (response.results && response.results.length > 0) {
      if (angular.isUndefined(_this.editItem.states)) {
        _this.editItem.states = [];
      }
      _this.editItem.states.push(response.results[0]);

      updateAlertStatus(_this.editItem);

      notifyObservers();
    }
  }

  function doAddState (action) {
    var state = {
      action: action,
      comment: _this.newComment,
      user_id: _this.currentUser.id,
      miq_alert_status_id: _this.editItem.id
    };
    if (action === 'assign') {
      state.assignee_id = _this.owner.id;
    }

    var resource = {
      action: "add",
      resource: state
    };

    var stateURL = alertsStatusURL + '/' + _this.editItem.id + '/alert_status_states';
    $http.post(stateURL, resource).success(processState);
  }

  function doAcknowledge () {
    doAddState('acknowledge');
  }

  function doUnacknowledge () {
    doAddState('unacknowledge');
  }

  function doAssign () {
    if (_this.editItem.assignee_id != _this.owner.id) {
      if (_this.owner) {
        doAddState('assign');

        if (_this.currentAcknowledged !== _this.editItem.acknowledged) {
          _this.currentAcknowledged ? doAcknowledge() : doUnacknowledge();
        }
      } else {
        doUnassign();
      }
    }
  }

  function doUnassign () {
    doAddState('unassign');
  }

  function doAddComment () {
    if (_this.newComment) {
      doAddState("comment");
    }
  }

  var modalOptions = {
    animation: true,
    backdrop: 'static',
    templateUrl: '/static/edit_alert_dialog.html',
    controller: 'EditAlertDialogController',
    resolve: {
      vm: function () {
        return _this;
      }
    }
  };

  function showEditDialog (item, title, showAssign, doneCallback, querySelector) {
    _this.editItem = item;
    _this.editTitle = title;
    _this.showAssign = showAssign;
    _this.owner = undefined;
    _this.currentAcknowledged = _this.editItem.acknowledged;
    for (var i = 0; i < _this.existingUsers.length; i++) {
      if (_this.existingUsers[i].id === item.assignee_id) {
        _this.owner = _this.existingUsers[i];
      }
    }
    _this.newComment = '';
    var modalInstance = $modal.open(modalOptions);
    modalInstance.result.then(doneCallback);

    $timeout(function () {
      var queryResult = $document[0].querySelector(querySelector);
      if (queryResult) {
        queryResult.focus();
      }
    }, 200);
  }

  function handleMenuAction (action, item) {
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
  }
}
