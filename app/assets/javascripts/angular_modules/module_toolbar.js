miqHttpInject(
  angular.module('ManageIQ.toolbar', [
    'miqStaticAssets', 'ui.bootstrap'
  ])
  .config(['$locationProvider', function ($locationProvider) {
    $locationProvider.html5Mode({
      enabled: false,
      requireBase: false,
    });
  }])
);
