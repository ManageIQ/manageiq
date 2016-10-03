angular.module('miq.util').factory('infraDashboardUtilsFactory', function() {
  var createProvidersIcon = function() {
    return {
      title: __("Providers"),
      count: 0,
      notifications: []
    };
  };
  var createClustersStatus = function() {
    return {
      title: __("Clusters"),
      iconClass: " pficon pficon-cluster",
      count: 0,
      notification: {}
    };
  };
  var createHostsStatus = function() {
    return {
      title: __("Hosts"),
      iconClass: "pficon pficon-screen",
      count: 0,
      notification: {}
    };
  };
  var createDatastoresStatus = function() {
    return {
      title:  __("Datastores"),
      iconClass: "fa fa-database",
      count: 0,
      notification: {}
    };
  };
  var createVmsStatus = function() {
    return {
      title: __("VMs"),
      iconClass: "pficon pficon-virtual-machine",
      count: 0,
      notification: {}
    };
  };
  var createMiqTemplatesStatus = function() {
    return {
      title: __("Templates"),
      iconClass: "pficon pficon-virtual-machine",
      count: 0,
      notification: {}
    };
  };

  var updateStatus = function (statusObject, data) {
    statusObject.notification = {};
    if (data) {
      statusObject.count = data.count;
      if (data.errorCount > 0) {
        statusObject.notification = {
          iconClass: "pficon pficon-error-circle-o",
          count: data.errorCount
        };
      } else if (data.warningCount > 0) {
        statusObject.notification = {
          iconClass: "pficon pficon-warning-triangle-o",
          count: data.warningCount
        };
      }

      if (statusObject.count > 0) {
        statusObject.href = data.href;
      }
    } else {
      statusObject.count = 0;
    }
  };
  var parseDate = function(date) {
    var myDate = Date.parse(date);
    return isNaN(myDate) ? date : myDate;
  };
  return {
    parseDate: parseDate,
    createProvidersIcon: createProvidersIcon,
    createClustersStatus: createClustersStatus,
    createDatastoresStatus: createDatastoresStatus,
    createHostsStatus: createHostsStatus,
    createVmsStatus: createVmsStatus,
    createMiqTemplatesStatus: createMiqTemplatesStatus,
    updateStatus: updateStatus
  };
});
