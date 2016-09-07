miqHttpInject(angular.module('miq.containers.providersModule')).controller('containers.deployProviderAuthSettingsController',
  ['$rootScope', '$scope', '$timeout', '$document', 'miqService',
  function($rootScope, $scope, $timeout, $document, miqService) {
    'use strict';
    $scope.deploymentDetailsAuthSettingsComplete = false;
    $scope.reviewTemplate = "/static/deploy_containers_provider/deploy-provider-auth-settings-review.html.haml";
    var firstShow = true;
    $scope.onShow = function () {
      if (firstShow) {
        $scope.data.authentication.htPassword = {
          users: [
            {username: '', password: ''}
          ]
        };
        $scope.data.authentication.ldap = {};
        $scope.data.authentication.requestHeader = {};
        $scope.data.authentication.openId = {};
        $scope.data.authentication.google = {};
        $scope.data.authentication.github = {};
        firstShow = false;

        $scope.$watch('data.authentication.mode', function() {
          $scope.validateForm();
        });
      }
      $scope.validateForm();
      miqService.dynamicAutoFocus('htpasswordUser' + ($scope.data.authentication.htPassword.users.length - 1));
      miqService.dynamicAutoFocus('initial-setting-input');

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

    var validString = function(value) {
      return angular.isDefined(value) && value.length > 0;
    };

    var validHtPassword = function() {
      if ($scope.data.authentication.mode !== 'htPassword') {
        return true;
      }

      if (angular.isUndefined($scope.data.authentication.htPassword)) {
        return false;
      }

      var invalid = $scope.data.authentication.htPassword.users.find(function (user) {
        return !validString(user.username) || !validString(user.password);
      });

      return invalid === undefined;
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
        validString($scope.data.authentication.github.clientSecret)
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

    $scope.clearAuthCA = function() {
      $scope.authTypeString === 'LDAP' ? $scope.data.authentication.ldap.ca = '' : $scope.data.authentication.requestHeader.clientCA = ''
      $scope.validateForm();
    };

    var onCAFileChosen = function(e) {
      var reader = new FileReader();
      reader.onload = function() {
        $scope.authTypeString === 'LDAP' ? $scope.data.authentication.ldap.ca = reader.result : $scope.data.authentication.requestHeader.clientCA = reader.result;
        $scope.$apply();
      };
      reader.readAsText(e.target.files[0]);
    };

    $scope.browseCAFile = function() {
      var uploadfile = $document[0].getElementById('browse-ca-input');
      uploadfile.onchange = onCAFileChosen;
      uploadfile.click();
    };

    $scope.addHtpasswordUser = function () {
      $scope.data.authentication.htPassword.users.push({username: '', password: ''});
      miqService.dynamicAutoFocus('htpasswordUser' + ($scope.data.authentication.htPassword.users.length - 1));
      $scope.validateForm();
    };

    $scope.removeHtpasswordUser = function (index) {
      $scope.data.authentication.htPassword.users.splice(index, 1);
      $scope.validateForm();
    };
  }
]);
