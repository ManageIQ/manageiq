miqHttpInject(angular.module('miq.containers.providersModule')).controller('containers.deployProviderReviewController',
  ['$rootScope', '$scope',
  function($rootScope, $scope) {
    'use strict';

    // Find the data!
    var next = $scope;
    while (angular.isUndefined($scope.data)) {
      next = next.$parent;
      if (angular.isUndefined(next)) {
        $scope.data = {};
      } else {
        $scope.data = next.wizardData;
      }
    }

    $scope.getProviderType = function() {
      if ($scope.data.providerType == 'openshiftOrigin') {
        return "OpenShift Origin";
      } else if ($scope.data.providerType == 'openshiftEnterprise') {
        return "OpenShift Enterprise";
      } else if ($scope.data.providerType == 'atomicPlatform') {
        return "Atomic Platform";
      }
    };

    $scope.getProviderDescription = function() {
      if ($scope.data.provisionOn == 'existingVms') {
        var provider = $scope.data.providers.find(function(provider) {
          return provider.id == $scope.data.existingProviderId;
        });
        return 'Use existing VMs from an existing provider: ' + (provider ? provider.name : "None");
      }
      else if ($scope.data.provisionOn == 'newVms') {
        var provider = $scope.data.providers.find(function(provider) {
          return provider.id == $scope.data.newVmProviderId;
        });
        return 'Use existing VMs from an existing provider: ' + (provider ? provider.name : "None");
      }
      else if ($scope.data.provisionOn == 'noProvider') {
        return 'Specify a list of machines to deploy on (No existing provider';
      }
    };

    $scope.getMasterCreationTemplate = function () {
      var selectedTemplate = $scope.data.nodeCreationTemplates.find(function(nextTemplate) {
        console.log(nextTemplate.id + " == " + $scope.data.masterCreationTemplateId + " is " + (nextTemplate.id == $scope.data.masterCreationTemplateId));
        return nextTemplate.id == $scope.data.masterCreationTemplateId;
      });
      return selectedTemplate ? selectedTemplate.name : "None";
    };

    $scope.getNodeCreationTemplate = function () {
      var selectedTemplate = $scope.data.nodeCreationTemplates.find(function(nextTemplate) {
        return nextTemplate.id === $scope.data.masterCreationTemplateId;
      });
      return selectedTemplate ? selectedTemplate.name : "None";
    };

    $scope.getAuthenticationType = function () {
      if ($scope.data.authentication.mode == 'all') {
        return "Allow All";
      } else if ($scope.data.authentication.mode == 'htPassword') {
        return "HTPassword";
      } else if ($scope.data.authentication.mode == 'ldap') {
        return "LDAP";
      } else if ($scope.data.authentication.mode == 'requestHeader') {
        return "Request Header";
      } else if ($scope.data.authentication.mode == 'openId') {
        return "OpenID Connect";
      } else if ($scope.data.authentication.mode == 'google') {
        return "Google";
      } else if ($scope.data.authentication.mode == 'github') {
        return "GitHub";
      } else {
        return "None";
      }
    };

    $scope.getStorageType = function() {
      if ($scope.data.storageType == 'nfs') {
        return "NFS";
      }
      else if ($scope.data.storageType == 'gluster') {
        return "Red Hat Gluster Storage";
      }
      else if ($scope.data.storageType == 'integratedNfs') {
        return "Integrated NFS (POCs only)";
      }
      else if ($scope.data.storageType == 'none') {
        return "None";
      }
    };
  }
]);
