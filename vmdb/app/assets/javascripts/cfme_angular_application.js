var cfmeAngularApplication = angular.module('cfmeAngularApplication', []);

cfmeAngularApplication.config(['$httpProvider', function($httpProvider) {
  $httpProvider.defaults.headers.common['X-CSRF-Token'] = jQuery('meta[name=csrf-token]').attr('content');
}]);
