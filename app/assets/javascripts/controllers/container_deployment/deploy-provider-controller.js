miqHttpInject(angular.module('miq.containers.providersModule', ['ui.bootstrap', 'patternfly', 'miq.dialogs', 'miq.wizard'])).controller('containers.deployProviderController',
  ['$rootScope', '$scope', '$timeout',
  function($rootScope, $scope, $timeout) {
    'use strict';

    $scope.showDeploymentWizard = false;
    ManageIQ.angular.scope = $scope;
    $scope.data = {};
    $scope.nodeData = {
      allNodes: [],
      filteredNodes: [],
      providerVMs: [],
      newVMs: [],
      userDefinedVMs: []
    };

    var initializeDeploymentWizard = function () {
      $scope.deployProviderReady = false;
      $scope.deployComplete = false;
      $scope.deployInProgress = false;
      $scope.deploySuccess = false;
      $scope.deployFailed = false;

      $scope.data = {
        providerName: '',
        providerType: 'openshiftOrigin',
        provisionOn: 'existingVms',
        masterCount: 0,
        nodeCount: 0,
        infraNodeCount: 0,
        cdnConfigType: 'satellite',
        authentication: {
          mode: 'all'
        }
      };

      $timeout(function() {
        $scope.data.existingProviders = $scope.deploymentData.providers;
        $scope.data.newVmProviders = $scope.deploymentData.provision;
        $scope.deployProviderReady = true;
      }, 5000);

      $scope.deploymentDetailsGeneralComplete = false;
      $scope.deployComplete = false;
      $scope.deployInProgress = false;
      $scope.nextButtonTitle = __("Next >");
    };

    var create_auth_object = function () {
      var auth = {};
      switch ($scope.data.authentication.mode) {
        case 'all':
          auth.type = "AuthenticationAllowAll";
          break;
        case 'htPassword':
          auth.type = 'AuthenticationHtpasswd';
          auth.users = $scope.data.authentication.htPassword.users;
          break;
        case 'ldap':
          auth.type = 'AuthenticationLdap';
          auth.id = $scope.data.authentication.ldap.id;
          auth.email = $scope.data.authentication.ldap.email;
          auth.name = $scope.data.authentication.ldap.name;
          auth.username = $scope.data.authentication.ldap.username;
          auth.bind_dn = $scope.data.authentication.ldap.bindDN;
          auth.password = $scope.data.authentication.ldap.bindPassword;
          auth.certificate_authority = $scope.data.authentication.ldap.ca;
          auth.insecure = $scope.data.authentication.ldap.insecure;
          auth.url = $scope.data.authentication.ldap.url;
          break;
        case 'requestHeader':
          auth.type = 'AuthenticationRequestHeader';
          auth.request_header_challenge_url = $scope.data.authentication.requestHeader.challengeUrl;
          auth.request_header_login_url = $scope.data.authentication.requestHeader.loginUrl;
          auth.certificate_authority = $scope.data.authentication.requestHeader.clientCA;
          auth.request_header_headers = $scope.data.authentication.requestHeader.headers;
          break;
        case 'openId':
          auth.type = 'AuthenticationOpenId';
          auth.userid = $scope.data.authentication.openId.clientId;
          auth.password = $scope.data.authentication.openId.clientSecret;
          auth.open_id_sub_claim = $scope.data.authentication.openId.subClaim;
          auth.open_id_authorization_endpoint = $scope.data.authentication.openId.authEndpoint;
          auth.open_id_token_endpoint = $scope.data.authentication.openId.tokenEndpoint;
          break;
        case 'google':
          auth.type = 'AuthenticationGoogle';
          auth.userid = $scope.data.authentication.google.clientId;
          auth.password = $scope.data.authentication.google.clientSecret;
          auth.google_hosted_domain = $scope.data.authentication.google.hostedDomain;
          break;
        case 'github':
          auth.type = 'AuthenticationGithub';
          auth.userid = $scope.data.authentication.github.clientId;
          auth.password = $scope.data.authentication.github.clientSecret;
          break;
      }
      return auth;
    };

    var create_nodes_object = function() {
      var nodes = [];
      var id = "";
      var name = "";
      var publicName = "";
      $scope.nodeData.allNodes.forEach(function(item) {
        if ($scope.data.provisionOn == 'existingVms') {
          id = item.id;
          name = item.name;
        }
        else if ($scope.data.provisionOn == 'noProvider') {
          name = item.vmName;
          publicName = item.publicName;
        }
        nodes.push({
          name: name,
          id: id,
          public_name: publicName,
          roles: {
            master: item.master,
            node: item.node,
            storage: item.storage,
            load_balancer: item.loadBalancer,
            dns: item.dns,
            etcd: item.etcd,
            infrastructure: item.infrastructure
          }
        });
      });
      nodes = nodes.filter(function (node) {
        return node.roles.master || node.roles.node || node.roles.storage
      });
      return nodes;
    };

    var create_deployment_resource = function() {
      var method_types = {
        existingVms: "existing_managed",
        newVms: "provision",
        noProvider: "unmanaged"
      };

      var resource = {
        provider_name: $scope.data.providerName,
        provider_type: $scope.data.providerType,
        method_type: method_types[$scope.data.provisionOn],
        rhsm_authentication: {
          mode: "AuthenticationRhsm",
          userid: $scope.data.rhnUsername,
          password: $scope.data.rhnPassword,
          rhsm_sku: $scope.data.rhnSKU,
          rhsm_server: $scope.data.rhnSatelliteUrl
        },
        ssh_authentication: {
          mode: "AuthPrivateKey",
          userid: $scope.data.deploymentUsername,
          auth_key: $scope.data.deploymentKey
        },
        nodes: create_nodes_object(),
        identity_authentication: create_auth_object()
      };

      if ($scope.data.provisionOn == 'existingVms') {
        resource.underline_provider_id = $scope.data.existingProviderId;
      } else if ($scope.data.provisionOn == 'newVms') {
        resource.underline_provider_id = $scope.data.newVmProviderId;
        resource.masters_creation_template_id = $scope.data.masterCreationTemplateId;
        resource.nodes_creation_template_id = $scope.data.nodeCreationTemplateId;
        resource.master_base_name = $scope.data.createMasterBaseName;
        resource.node_base_name = $scope.data.createNodesBaseName;
      }
      return resource;
    };

    $scope.ready = false;
    var url = '/api/container_deployments/container_deployment_data';
    API.get(url).then(function (response) {
      'use strict';
      $scope.deploymentData = response.data;
      initializeDeploymentWizard();
      $scope.ready = true;
    });

    $scope.data = {};
    $scope.deployComplete = false;
    $scope.deployInProgress = false;

    var startDeploy = function () {
      $scope.deployInProgress = true;
      $timeout(function () {
        var url = '/api/container_deployments';
        var resource = create_deployment_resource();
        API.post(url, {"action" : "create", "resource" :  resource}).then(function (response) {
          'use strict';
          $scope.deployInProgress = true;
          var automationID = response
        });

        if ($scope.deployInProgress) {
          $scope.deployInProgress = false;
          $scope.deployComplete = false;
          $scope.deploySuccess = false;
          $scope.deployFailed = false;
          $scope.deployFailureMessage = __("An unknown error has occurred.");
        }
      }, 5000);
    };

    $scope.nextCallback = function(step) {
      if (step.stepId === 'review-summary') {
        startDeploy();
      }
      return true;
    };
    $scope.backCallback = function(step) {
      return true;
    };

    $scope.$on("wizard:stepChanged", function(e, parameters) {
      if (parameters.step.stepId == 'review-summary') {
        $scope.nextButtonTitle = __("Deploy");
      } else if (parameters.step.stepId == 'review-progress') {
        $scope.nextButtonTitle = __("Close");
      } else {
        $scope.nextButtonTitle = __("Next >");
      }
    });

    $scope.showDeploymentWizard = false;
    $scope.showListener = function() {
      if (!$scope.showDeploymentWizard) {
        initializeDeploymentWizard();
        $scope.showDeploymentWizard = true;
      }
    };

    $scope.cancelDeploymentWizard = function () {
      if (!$scope.deployInProgress) {
        $scope.showDeploymentWizard = false;
      }
    };

    $scope.cancelWizard = function () {
      $scope.showDeploymentWizard = false;
      return true;
    };

    $scope.finishedWizard = function () {
      $rootScope.$emit('deployProvider.finished');
      $scope.showDeploymentWizard = false;
      return true;
    };
  }
]);
