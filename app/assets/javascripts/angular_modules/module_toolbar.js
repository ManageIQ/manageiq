miqHttpInject(
  angular.module('ManageIQ.toolbar', [
    'miqStaticAssets', 'ui.bootstrap'
  ])
  .config(function ($locationProvider) {
    $locationProvider.html5Mode({
      enabled: true,
      requireBase: false
    })
  })
);
