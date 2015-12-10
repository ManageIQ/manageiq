ManageIQ.angular.app = angular.module('ManageIQ', [
  'ui.bootstrap',
  'patternfly',
  'frapontillo.bootstrap-switch',
]);

ManageIQ.angular.app.config(['$httpProvider', function($httpProvider) {
  $httpProvider.defaults.headers.common['X-CSRF-Token'] = jQuery('meta[name=csrf-token]').attr('content');
}]);

function miq_bootstrap(selector, app) {
  app = app || 'ManageIQ';

  return angular.bootstrap($(selector), [app], { strictDi: true });
}
