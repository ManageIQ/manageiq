miqHttpInject(angular.module('miq.containers.providersModule')).controller('containers.deployProviderAuthSettingsController',
  ['$rootScope', '$scope', '$timeout', '$document',
  function($rootScope, $scope, $timeout, $document) {
    'use strict';
    $scope.deploymentDetailsAuthSettingsComplete = false;
    $scope.reviewTemplate = "/static/deploy-provider-auth-settings-review.html";
    var firstShow = true;
    $scope.onShow = function () {
      if (firstShow) {
        $scope.data.authentication.htPassword = {};
        $scope.data.authentication.ldap = {};
        $scope.data.authentication.requestHeader = {};
        $scope.data.authentication.openId = {};
        $scope.data.authentication.google = {};
        $scope.data.authentication.github = {};
        firstShow = false;
      }
      $scope.validateForm();
      $timeout(function() {
        var queryResult = $document[0].getElementById('initial-setting-input');
        if (queryResult) {
          queryResult.focus();
        }
      }, 200);

      switch ($scope.data.authentication.mode) {
        case 'htPassword':
          $scope.authTypeString = 'HTPassword';
          break;
        case 'ldap':
          $scope.authTypeString = 'LDAP';
          break;
        case 'requestHeader':
          $scope.authTypeString = 'Request Header';
          break;
        case 'openId':
          $scope.authTypeString = 'OpenID Connect';
          break;
        case 'google':
          $scope.authTypeString = 'Google';
          break;
        case 'github':
          $scope.authTypeString = 'GitHub';
          break;
      }
    };

    $scope.$watch('data.authentication.mode', function() {
      $scope.validateForm();
    });

    var validString = function(value) {
      return angular.isDefined(value) && value.length > 0;
    };

    var validHtPassword = function() {
      if ($scope.data.authentication.mode !== 'htPassword') {
        return true;
      }

      return (
        !angular.isUndefined($scope.data.authentication.htPassword) &&
        validString($scope.data.authentication.htPassword.username) &&
        validString($scope.data.authentication.htPassword.password) &&
        validString($scope.data.authentication.htPassword.filePath)
      );
    };

    var validLdap = function() {
      if ($scope.data.authentication.mode !== 'ldap') {
        return true;
      }

      return (
        !angular.isUndefined($scope.data.authentication.ldap) &&
        validString($scope.data.authentication.ldap.id) &&
        validString($scope.data.authentication.ldap.email) &&
        validString($scope.data.authentication.ldap.name) &&
        validString($scope.data.authentication.ldap.username) &&
        validString($scope.data.authentication.ldap.email) &&
        validString($scope.data.authentication.ldap.bindDN) &&
        validString($scope.data.authentication.ldap.bindPassword) &&
        validString($scope.data.authentication.ldap.ca) &&
        validString($scope.data.authentication.ldap.insecure) &&
        validString($scope.data.authentication.ldap.url)
      );
    };

    var validRequestHeader = function() {
      if ($scope.data.authentication.mode !== 'requestHeader') {
        return true;
      }

      return (
        !angular.isUndefined($scope.data.authentication.requestHeader) &&
        validString($scope.data.authentication.requestHeader.challengeUrl) &&
        validString($scope.data.authentication.requestHeader.loginUrl) &&
        validString($scope.data.authentication.requestHeader.clientCA) &&
        validString($scope.data.authentication.requestHeader.headers)
      );
    };

    var validOpenId = function() {
      if ($scope.data.authentication.mode !== 'openId') {
        return true;
      }

      return (
        !angular.isUndefined($scope.data.authentication.openId) &&
        validString($scope.data.authentication.openId.clientId) &&
        validString($scope.data.authentication.openId.clientSecret) &&
        validString($scope.data.authentication.openId.subClaim) &&
        validString($scope.data.authentication.openId.authEndpoint) &&
        validString($scope.data.authentication.openId.tokenEndpoint)
      );
    };

    var validGoogle = function() {
      if ($scope.data.authentication.mode !== 'google') {
        return true;
      }

      return (
        !angular.isUndefined($scope.data.authentication.google) &&
        validString($scope.data.authentication.google.clientId) &&
        validString($scope.data.authentication.google.clientSecret) &&
        validString($scope.data.authentication.google.hostedDomain)
      );
    };

    var validGithub = function() {
      if ($scope.data.authentication.mode !== 'github') {
        return true;
      }

      return (
        !angular.isUndefined($scope.data.authentication.github) &&
        validString($scope.data.authentication.github.clientId) &&
        validString($scope.data.authentication.github.clientSecret) &&
        validString($scope.data.authentication.github.hostedDomain)
      );
    };

    $scope.validateForm = function() {
      $scope.deploymentDetailsAuthSettingsComplete =
        validHtPassword() &&
        validLdap() &&
        validRequestHeader() &&
        validOpenId() &&
        validGoogle() &&
        validGithub();
    };
  }
]);
