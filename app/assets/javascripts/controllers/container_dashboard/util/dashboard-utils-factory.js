angular.module('miq.util').factory('dashboardUtilsFactory', function() {
  var createProvidersStatus = function() {
    return {
      title: __("Providers"),
      count: '-',
      notifications: []
    };
  };
  var createNodesStatus = function() {
    return {
      title: __("Nodes"),
      iconClass: "pficon pficon-container-node",
      count: '-',
      notification: {}
    };
  };
  var createContainersStatus = function() {
    return {
      title: __("Containers"),
      iconClass: "fa fa-cube",
      count: '-',
      notification: {}
    };
  };
  var createRegistriesStatus = function() {
    return {
      title:  __("Registries"),
      iconClass: "pficon pficon-registry",
      count: '-',
      notification: {}
    };
  };
  var createProjectsStatus = function() {
    return {
      title: __("Projects"),
      iconClass: "pficon pficon-project",
      count: '-',
      notification: {}
    };
  };
  var createPodsStatus = function() {
    return {
      title: __("Pods"),
      iconClass: "fa fa-cubes",
      count: '-',
      notification: {}
    };
  };
  var createServicesStatus = function() {
    return {
      title: __("Services"),
      iconClass: "pficon pficon-service",
      count: '-',
      notification: {}
    };
  };
  var createImagesStatus = function() {
    return {
      title: __("Images"),
      iconClass: "pficon pficon-image",
      count: '-',
      notification: {}
    };
  };
  var createRoutesStatus = function() {
    return {
      title: __("Routes"),
      iconClass: "pficon pficon-route",
      count: '-',
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
    createProvidersStatus: createProvidersStatus,
    createNodesStatus: createNodesStatus,
    createContainersStatus: createContainersStatus,
    createRegistriesStatus: createRegistriesStatus,
    createProjectsStatus: createProjectsStatus,
    createPodsStatus: createPodsStatus,
    createServicesStatus: createServicesStatus,
    createImagesStatus: createImagesStatus,
    createRoutesStatus: createRoutesStatus,
    updateStatus: updateStatus
  };
});
