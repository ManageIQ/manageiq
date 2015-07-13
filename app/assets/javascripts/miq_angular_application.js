var miqAngularApplication = angular.module('miqAngularApplication', ['ui.bootstrap']);

miqAngularApplication.config([ '$httpProvider', function ($httpProvider) {
  $httpProvider.defaults.headers.common['X-CSRF-Token'] = jQuery('meta[name=csrf-token]').attr('content');
} ]);
