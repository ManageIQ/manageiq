miqHttpInject(angular.module('miq.containers.providersModule')).controller('containers.deployProviderMasterNodesController',
  ['$rootScope', '$scope', 'miqService', '$document',
  function($rootScope, $scope, miqService, $document) {
    'use strict';

    $scope.deploymentDetailsMasterNodesComplete = false;
    $scope.reviewTemplate = "/static/deploy_containers_provider/deploy-provider-master-nodes-review.html.haml";
    $scope.data.deploymentKey = '';
    $scope.data.deploymentUsername = '';

    $scope.editRolesStatus = {
      open: false
    };

    var currentProvisionOn = '';
    var currentProviderId = '';

    var updateNodes = function () {
      if ($scope.data.provisionOn == 'existingVms') {
        $scope.nodeData.allNodes = $scope.nodeData.providerVMs;
      } else if ($scope.data.provisionOn == 'newVms') {
        $scope.nodeData.allNodes = $scope.nodeData.newVMs;
        $scope.updateNodeSettings();
      } else if ($scope.data.provisionOn == 'noProvider') {
        $scope.nodeData.allNodes = $scope.nodeData.userDefinedVMs;
      }
      applyFilters($scope.filterConfig.appliedFilters);
      updateSetNodeTypeButtons();
      $scope.updateAllNodesSelected();
    };

    var updateExistingVMs = function () {
      if ($scope.data.provisionOn == 'existingVms') {
        $scope.data.existingProvider = $scope.data.existingProviders.find(function(provider){
          return provider.provider.id == $scope.data.existingProviderId
        });
        $scope.nodeData.providerVMs = $scope.data.existingProvider.vms;
        $scope.nodeData.providerVMs.forEach(function(item) {
          item.master = false;
          item.node = false;
          item.storage = false;
          item.loadBalancer = false;
          item.dns = false;
          item.etcd = false;
          item.infrastructure = false;
        });

        updateNodes();
        $scope.updateNodeSettings();
      }
    };

    $scope.sortConfig = {};

    $scope.onShow = function () {
      if (currentProvisionOn != $scope.data.provisionOn) {
        if ($scope.data.provisionOn == 'existingVms')
          updateExistingVMs();
        else {
          updateNodes();
        }
      } else if ($scope.data.provisionOn == 'existingVms' && $scope.data.existingProviderId != currentProviderId) {
        updateExistingVMs();
      } else {
        $scope.updateNodeSettings();
      }
      currentProvisionOn = $scope.data.provisionOn;
      currentProviderId = $scope.data.existingProviderId;

      var elementId = $scope.data.provisionOn == 'newVms' ? 'create-master-base-name' : 'deploy-key';
      miqService.dynamicAutoFocus(elementId);
    };

    $scope.masterCountValid = function(count) {
      if (count !== 1 && count !== 3 && count !== 5) {
        $scope.mastersWarning = __("The number of Masters must be 1, 3, or 5");
        return false;
      } else {
        return true;
      }
    };

    $scope.nodeCountValid = function(count) {
      if (count < 1) {
        $scope.nodesWarning = __("You must select at least one Node");
        return false;
      } else {
        return true;
      }
    };

    $scope.storageNodeCountValid = function(count) {
      if ($scope.data.serverConfigType == 'integratedNFS' &&  count != 1) {
        $scope.storageNodeWarning = __("You must select one Storage Node when using Integrated NFS storage");
        return false;
      } else if (count > 1) {
        $scope.storageNodeWarning = __("You can only specify one Storage Node");
        return false;
      } else {
        return true;
      }
    };

    $scope.dnsNodeCountValid = function(count) {
      if (count > 1) {
        $scope.dnsNodeWarning = __("You can specify at most one DNS Node");
        return false;
      } else {
        return true;
      }
    };

    $scope.validateNodeSettings = function () {
      var valid = true;

      if ($scope.data.loadBalancerNodes && $scope.data.loadBalancerNodes.length > 0) {
        $scope.data.loadBalancerNodes.forEach(function (item) {
          if (!item.node && !item.master) {
            valid = false;
            $scope.loadBalancerWarning = __("Load balancers can only be assigned to Masters or Nodes");
          }
        });
      }
      if ($scope.data.dnsNodes && $scope.data.dnsNodes.length > 0) {
        $scope.data.dnsNodes.forEach(function (item) {
          if (!item.node && !item.master) {
            valid = false;
            $scope.dnsNodeWarning = __("DNS can only be assigned to Masters or Nodes");
          }
        });
      }
      if ($scope.data.etcdNodes && $scope.data.etcdNodes.length > 0) {
        $scope.data.etcdNodes.forEach(function (item) {
          if (!item.node && !item.master) {
            valid = false;
            $scope.etcdNodeWarning = __("Etcd can only be assigned to Masters or Nodes");
          }
        });
      }
      if ($scope.data.infrastructureNodes && $scope.data.infrastructureNodes.length > 0) {
        $scope.data.infrastructureNodes.forEach(function (item) {
          if (!item.node) {
            valid = false;
            $scope.infrastructureWarning = __("Infrastructure can only be assigned to Nodes");
          }
        });
      }

      return valid;
    };

    $scope.validateNodeCounts = function () {
      $scope.mastersCount = $scope.data.masters ? $scope.data.masters.length : 0;
      $scope.nodesCount = $scope.data.nodes ? $scope.data.nodes.length : 0;
      $scope.storageCount = $scope.data.storageNodes ? $scope.data.storageNodes.length : 0;
      $scope.loadBalancerCount = $scope.data.loadBalancerNodes ? $scope.data.loadBalancerNodes.length : 0;
      $scope.dnsCount = $scope.data.dnsNodes ? $scope.data.dnsNodes.length : 0;
      $scope.etcdCount = $scope.data.etcdNodes ? $scope.data.etcdNodes.length : 0;
      $scope.infrastructureCount = $scope.data.infrastructureNodes ? $scope.data.infrastructureNodes.length : 0;

      $scope.mastersWarning = "";
      $scope.nodesWarning = "";
      $scope.storageNodeWarning = "";
      $scope.dnsNodeWarning = "";
      $scope.loadBalancerWarning = "";
      $scope.dnsNodeWarning = "";
      $scope.etcdNodeWarning = "";
      $scope.infrastructureWarning = "";

      var mastersValid = $scope.masterCountValid($scope.mastersCount);
      var nodesValid = $scope.nodeCountValid($scope.nodesCount);
      var storageNodesValid = $scope.storageNodeCountValid($scope.storageCount);
      var dnsNodesValid = $scope.dnsNodeCountValid($scope.dnsCount);
      var settingsValid = $scope.validateNodeSettings ();

      return mastersValid && nodesValid && storageNodesValid && dnsNodesValid && settingsValid;
    };

    $scope.setMasterNodesComplete = function(value) {
      $scope.deploymentDetailsMasterNodesComplete = value;
    };

    $scope.nodeData.allNodes = [];
    $scope.nodeData.filteredNodes = [];

    var matchesFilter = function (item, filter) {
      var match = true;
      if (filter.id === 'name') {
        match = item.name.match(filter.value) !== null;
      } else if (filter.id === 'role') {
        if (filter.value == 'Unset') {
          match = !item.master && !item.node && !item.storage && !item.loadBalancer && !item.dns && !item.etcd && !item.infrastructure;
        } else if (filter.value == 'Master') {
          match = item.master;
        } else if (filter.value == 'Node') {
          match = item.node;
        } else if (filter.value == 'Storage') {
          match = item.storage;
        } else if (filter.value == 'Load Balancer') {
          match = item.loadBalancer;
        } else if (filter.value == 'DNS') {
          match = item.dns;
        } else if (filter.value == 'Etcd') {
          match = item.etcd;
        } else if (filter.value == 'Infrastructure') {
          match = item.infrastructure;
        }
      }
      return match;
    };

    var matchesFilters = function (item) {
      var matches = true;

      $scope.filterConfig.appliedFilters.forEach(function (filter) {
        if (!matchesFilter(item, filter)) {
          matches = false;
          return false;
        }
      });
      return matches;
    };

    var applyFilters = function () {
      if ($scope.filterConfig.appliedFilters && $scope.filterConfig.appliedFilters.length > 0) {
        $scope.nodeData.filteredNodes = $scope.nodeData.allNodes.filter(matchesFilters);
      } else {
        $scope.nodeData.filteredNodes = $scope.nodeData.allNodes;
      }

      $scope.filterConfig.resultsCount = $scope.nodeData.filteredNodes.length;
    };

    $scope.filterConfig = {
      fields: [
        {
          id: 'name',
          title: __('Name'),
          placeholder: 'Filter by Name...',
          filterType: 'text'
        },
        {
          id: 'role',
          title: __('Role'),
          placeholder: 'Filter by Role...',
          filterType: 'select',
          filterValues: ['Unset', 'Master', 'Node', 'Storage', 'Load Balancer', 'DNS', 'Etcd', 'Infrastructure']
        }
      ],
      resultsCount: $scope.nodeData.filteredNodes.length,
      appliedFilters: [],
      onFilterChange: applyFilters
    };

    $scope.compareFn = function (item1, item2) {
      var compValue = 0;
      if ($scope.sortConfig.currentField.id === 'name') {
        compValue = item1.name.localeCompare(item2.name);
      } else {
        if ($scope.sortConfig.currentField.id === 'role') {
          if (item1.master != item2.master) {
            if (item1.master) {
              compValue = -1;
            } else {
              compValue = 1;
            }
          }
          else if (item1.node != item2.node) {
            if (item1.node) {
              compValue = -1;
            } else {
              compValue = 1;
            }
          }
          else if (item1.storage != item2.storage) {
            if (item1.storage) {
              compValue = -1;
            } else {
              compValue = 1;
            }
          }
          else if (item1.loadBalancer != item2.loadBalancer) {
            if (item1.loadBalancer) {
              compValue = -1;
            } else {
              compValue = 1;
            }
          }
          else if (item1.dns != item2.dns) {
            if (item1.dns) {
              compValue = -1;
            } else {
              compValue = 1;
            }
          }
          else if (item1.etcd != item2.etcd) {
            if (item1.etcd) {
              compValue = -1;
            } else {
              compValue = 1;
            }
          }
          else if (item1.loadBalancer != item2.loadBalancer) {
            if (item1.loadBalancer) {
              compValue = -1;
            } else {
              compValue = 1;
            }
          }
        } else if ($scope.sortConfig.currentField.id === 'cpus') {
          compValue = item1.cpus - item2.cpus;
        } else if ($scope.sortConfig.currentField.id === 'memory') {
          compValue = item1.memory - item2.memory;
        } else if ($scope.sortConfig.currentField.id === 'diskSize') {
          compValue = item1.diskSize - item2.diskSize;
        }
        if (compValue === 0) {
          compValue = item1.name.localeCompare(item2.name);
        }
      }

      if (!$scope.sortConfig.isAscending) {
        compValue = compValue * -1;
      }

      return compValue;
    };

    $scope.sortChange = function () {
      $scope.nodeData.allNodes.sort($scope.compareFn);
      $scope.nodeData.filteredNodes.sort($scope.compareFn);
    };

    var updateSetNodeTypeButtons = function () {
      var selectedCount = $scope.nodeData.filteredNodes.filter(function(node) {
        return node.selected;
      }).length;
      $scope.disableMasterNodeActions = selectedCount === 0;

      $scope.nodeData.allNodesSelected = (selectedCount > 0) && (selectedCount === $scope.nodeData.filteredNodes.length);
    };

    var validString = function(value) {
      return angular.isDefined(value) && value.length > 0;
    };

    $scope.updateNodeSettings = function () {
      $scope.data.masters = $scope.nodeData.allNodes.filter(function(node) {
        return node.master === true;
      });
      $scope.data.nodes = $scope.nodeData.allNodes.filter(function(node) {
        return node.node === true;
      });
      $scope.data.storageNodes = $scope.nodeData.allNodes.filter(function(node) {
        return node.storage === true;
      });
      $scope.data.loadBalancerNodes = $scope.nodeData.allNodes.filter(function(node) {
        return node.loadBalancer === true;
      });
      $scope.data.dnsNodes = $scope.nodeData.allNodes.filter(function(node) {
        return node.dns === true;
      });
      $scope.data.etcdNodes = $scope.nodeData.allNodes.filter(function(node) {
        return node.etcd === true;
      });
      $scope.data.infrastructureNodes = $scope.nodeData.allNodes.filter(function(node) {
        return node.infrastructure === true;
      });

      var inputsValid = $scope.data.provisionOn == 'newVms'? true : validString($scope.data.deploymentKey) && validString($scope.data.deploymentUsername);

      $scope.setMasterNodesComplete($scope.validateNodeCounts() && inputsValid);
      $scope.nodeData.allNodes.forEach(function (item) {
        item.selected = false;
      });

      applyFilters();
      $scope.sortChange();
      updateSetNodeTypeButtons();
    };

    $scope.validateForm = function() {
      $scope.updateNodeSettings();
    };

    $scope.clearDeploymentKey = function() {
      $scope.data.deploymentKey = '';
      $scope.validateForm();
    };

    var onKeyFileChosen = function(e) {
      var reader = new FileReader();
      reader.onload = function() {
        $scope.data.deploymentKey = reader.result;
        $scope.$apply();
      };
      reader.readAsText(e.target.files[0]);
    };

    $scope.browseKeyFile = function() {
      var uploadfile = $document[0].getElementById('browse-key-input');
      uploadfile.onchange = onKeyFileChosen;
      uploadfile.click();
    };

    $scope.removeRoles = function () {
      $scope.nodeData.allNodes.forEach(function(node) {
        if (node.selected) {
          node.master = false;
          node.node = false;
          node.storage = false;
          node.loadBalancer = false;
          node.dns = false;
          node.etcd = false;
          node.infrastructure = false;
        }
      });
      $scope.updateNodeSettings();
    };

    $scope.updateSelectedRoles = function() {
      var selectedNodes =  $scope.nodeData.allNodes.filter(function(node) {
        return node.selected === true;
      });

      selectedNodes.forEach(function(item) {
        item.master = $scope.toolbarMenu.master;
        item.node = $scope.toolbarMenu.node;
        item.storage = $scope.toolbarMenu.storage;
        item.loadBalancer = $scope.toolbarMenu.loadBalancer;
        item.dns = $scope.toolbarMenu.dns;
        item.etcd = $scope.toolbarMenu.etcd;
        item.infrastructure = $scope.toolbarMenu.infrastructure;
      });
      $scope.updateNodeSettings();
      $scope.editRolesStatus.open = false;
    };

    $scope.toolbarMenuSelectAll = function () {
      $scope.toolbarMenu.master = true;
      $scope.toolbarMenu.node = true;
      $scope.toolbarMenu.storage = true;
      $scope.toolbarMenu.loadBalancer = true;
      $scope.toolbarMenu.dns = true;
      $scope.toolbarMenu.etcd = true;
      $scope.toolbarMenu.infrastructure = true;
    };

    $scope.onToolbarMenuShow = function() {
      var selectedNodes =  $scope.nodeData.allNodes.filter(function(node) {
        return node.selected === true;
      });

      var allMasters = selectedNodes.filter(function(node) {
          return node.master === true;
        }).length === selectedNodes.length;
      var allNodes = selectedNodes.filter(function(node) {
          return node.node === true;
        }).length === selectedNodes.length;
      var allStorage = selectedNodes.filter(function(node) {
          return node.storage === true;
        }).length === selectedNodes.length;
      var allLoadBalancers = selectedNodes.filter(function(node) {
          return node.loadBalancer === true;
        }).length === selectedNodes.length;
      var allDNS = selectedNodes.filter(function(node) {
          return node.dns === true;
        }).length === selectedNodes.length;
      var allEtcd = selectedNodes.filter(function(node) {
          return node.etcd === true;
        }).length === selectedNodes.length;
      var allInfrastructure = selectedNodes.filter(function(node) {
          return node.infrastructure === true;
        }).length === selectedNodes.length;

      $scope.toolbarMenu = {
        master: allMasters,
        node: allNodes,
        storage: allStorage,
        loadBalancer: allLoadBalancers,
        dns: allDNS,
        etcd: allEtcd,
        infrastructure: allInfrastructure
      };
    };

    $scope.addMaster = function(item) {
      item.master = true;
      $scope.updateNodeSettings();
    };

    $scope.addNode = function(item) {
      item.node = true;
      $scope.updateNodeSettings();
    };

    $scope.addStorage = function(item) {
      item.storage = true;
      $scope.updateNodeSettings();
    };

    $scope.addLoadBalancer = function(item) {
      item.loadBalancer = true;
      $scope.updateNodeSettings();
    };

    $scope.addDns = function(item) {
      item.dns = true;
      $scope.updateNodeSettings();
    };

    $scope.addEtcd = function(item) {
      item.etcd = true;
      $scope.updateNodeSettings();
    };

    $scope.addInfrastructure = function(item) {
      item.infrastructure = true;
      $scope.updateNodeSettings();
    };

    $scope.removeMaster = function(item) {
      item.master = false;
      $scope.updateNodeSettings();
    };

    $scope.removeNode = function(item) {
      item.node = false;
      $scope.updateNodeSettings();
    };

    $scope.removeStorage = function(item) {
      item.storage = false;
      $scope.updateNodeSettings();
    };

    $scope.removeLoadBalancer = function(item) {
      item.loadBalancer = false;
      $scope.updateNodeSettings();
    };

    $scope.removeDns = function(item) {
      item.dns = false;
      $scope.updateNodeSettings();
    };

    $scope.removeEtcd = function(item) {
      item.etcd = false;
      $scope.updateNodeSettings();
    };

    $scope.removeInfrastructure = function(item) {
      item.infrastructure = false;
      $scope.updateNodeSettings();
    };

    $scope.nodeData.allNodesSelected = false;
    $scope.nodeData.allFilteredNodesSelected = false;

    $scope.toggleAllNodesSelected = function() {
      $scope.nodeData.allNodesSelected = !$scope.nodeData.allNodesSelected;
      $scope.nodeData.allNodes.forEach(function (item, index) {
        item.selected = $scope.nodeData.allNodesSelected;
      });
      updateSetNodeTypeButtons();
    };

    $scope.toggleAllFilteredNodesSelected = function() {
      $scope.nodeData.allFilterdNodesSelected = !$scope.nodeData.allFilterdNodesSelected;
      $scope.nodeData.filteredNodes.forEach(function (item, index) {
        item.selected = $scope.nodeData.allFilterdNodesSelected;
      });
      updateSetNodeTypeButtons();
    };

    $scope.updateAllNodesSelected = function() {
      var found = $scope.nodeData.allNodes.find(function(node) {
        return !node.selected;
      });
      $scope.nodeData.allNodesSelected = (found === undefined);

      found = $scope.nodeData.filteredNodes.find(function(node) {
        return !node.selected;
      });
      $scope.nodeData.allFilterdNodesSelected = (found === undefined);
    };

    $scope.toggleNodeSelected = function(node) {
      node.selected = !node.selected;
      $scope.updateAllNodesSelected ();
      updateSetNodeTypeButtons();
    };

    $scope.updateNodeSettings();
  }
]);
