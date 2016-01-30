ManageIQ.angularApplication = angular.module('ManageIQ.angularApplication', ['ui.bootstrap', 'patternfly', 'frapontillo.bootstrap-switch']);
ManageIQ.angularApplication.config([ '$httpProvider', function ($httpProvider) {
  $httpProvider.defaults.headers.common['X-CSRF-Token'] = jQuery('meta[name=csrf-token]').attr('content');
} ]);
