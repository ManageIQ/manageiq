angular.module('containerDashboard').factory('ContainerDashboardUtils', [function ContainerDashboardUtils () {
  var createProvidersStatus = function() {
    return {
      title: "Providers",
      count: 0,
      href: "../ems_container/show_list",
      notifications: []
    };
  };
  var createNodesStatus = function() {
    return {
      title: "Nodes",
      iconClass: "pficon pficon-container-node",
      count: 0,
      href: "../container_node/show_list",
      notification: {}
    };
  };
  var createContainersStatus = function() {
    return {
      title: "Containers",
      iconClass: "fa fa-cube",
      count: 0,
      href: "../container/explorer",
      notification: {}
    };
  };
  var createRegistriesStatus = function() {
    return {
      title:  "Registries",
      iconClass: "pficon pficon-registry",
      count: 0,
      href: "../container_image_registry/show_list",
      notification: {}
    };
  };
  var createProjectsStatus = function() {
    return {
      title: "Projects",
      iconClass: "pficon pficon-project",
      count: 0,
      href: "../container_project/show_list",
      notification: {}
    };
  };
  var createPodsStatus = function() {
    return {
      title: "Pods",
      iconClass: "fa fa-cubes",
      count: 0,
      href: "../container_group/show_list",
      notification: {}
    };
  };
  var createServicesStatus = function() {
    return {
      title: "Services",
      iconClass: "pficon pficon-service",
      count: 0,
      href: "../container_service/show_list",
      notification: {}
    };
  };
  var createImagesStatus = function() {
    return {
      title: "Images",
      iconClass: "pficon pficon-image",
      count: 0,
      href: "../container_image/show_list",
      notification: {}
    };
  };
  var createRoutesStatus = function() {
    return {
      title: "Routes",
      iconClass: "pficon pficon-route",
      count: 0,
      href: "../container_route/show_list",
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
      }
      else if (data.warningCount > 0) {
        statusObject.notification = {
          iconClass: "pficon pficon-warning-triangle-o",
          count: data.warningCount
        };
      }
    } else {
      statusObject.count = 0;
    }
  };


  return {
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
}]);
