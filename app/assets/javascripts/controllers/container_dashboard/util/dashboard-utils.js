angular.module('miq.util').factory('miq.util', [function dashboardUtilsFactory () {
  var createProvidersStatus = function() {
    return {
      title: "Providers",
      count: 0,
      notifications: []
    };
  };
  var createNodesStatus = function() {
    return {
      title: "Nodes",
      iconClass: "pficon pficon-container-node",
      count: 0,
      notification: {}
    };
  };
  var createContainersStatus = function() {
    return {
      title: "Containers",
      iconClass: "fa fa-cube",
      count: 0,
      notification: {}
    };
  };
  var createRegistriesStatus = function() {
    return {
      title:  "Registries",
      iconClass: "pficon pficon-registry",
      count: 0,
      notification: {}
    };
  };
  var createProjectsStatus = function() {
    return {
      title: "Projects",
      iconClass: "pficon pficon-project",
      count: 0,
      notification: {}
    };
  };
  var createPodsStatus = function() {
    return {
      title: "Pods",
      iconClass: "fa fa-cubes",
      count: 0,
      notification: {}
    };
  };
  var createServicesStatus = function() {
    return {
      title: "Services",
      iconClass: "pficon pficon-service",
      count: 0,
      notification: {}
    };
  };
  var createImagesStatus = function() {
    return {
      title: "Images",
      iconClass: "pficon pficon-image",
      count: 0,
      notification: {}
    };
  };
  var createRoutesStatus = function() {
    return {
      title: "Routes",
      iconClass: "pficon pficon-route",
      count: 0,
      notification: {}
    };
  };
  var createReplicatorsStatus = function() {
    return {
        title: "Replicators",
        iconClass: "pficon pficon-replicator",
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
      }
      else if (data.warningCount > 0) {
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

  var heatmapSort = function(a, b) {return b.value - a.value};

  var createAllStatuses = function() {
    return {
      providers: createProvidersStatus(),
      container_nodes: createNodesStatus(),
      containers: createContainersStatus(),
      container_image_registries: createRegistriesStatus(),
      container_projects: createProjectsStatus(),
      container_groups: createPodsStatus(),
      container_services: createServicesStatus(),
      container_images: createImagesStatus(),
      container_routes: createRoutesStatus(),
      container_replicators: createReplicatorsStatus()
    }
  };

  var updateAllStatuses = function(objStatues, data) {
      for (var key in data){
          updateStatus(objStatues[key], data[key]);
      }
  };

  return {
    heatmapSort: heatmapSort,
    createProvidersStatus: createProvidersStatus,
    createNodesStatus: createNodesStatus,
    createContainersStatus: createContainersStatus,
    createRegistriesStatus: createRegistriesStatus,
    createProjectsStatus: createProjectsStatus,
    createPodsStatus: createPodsStatus,
    createServicesStatus: createServicesStatus,
    createImagesStatus: createImagesStatus,
    createRoutesStatus: createRoutesStatus,
    createReplicatorsStatus: createReplicatorsStatus,
    createAllStatuses: createAllStatuses,
    updateStatus: updateStatus,
    updateAllStatuses: updateAllStatuses
  };
}]);
