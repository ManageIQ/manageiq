describe('middleware.providers.miqNewProviderController', function() {
  beforeEach(module('miq.provider'));
  var mock_types = getJSONFixture('middleware/types.json');
  var $controller, $httpBackend, $scope, $q, MiQNotificationService, $state, $urlRouter;

  var validObject = {
    type:"default",
    zone:"Default Zone",
    server_emstype:"Hawkular",
    name:"hawkular",
    hostname:"localhost",
    port:8080,
    default_userid:"jdoe",
    default_password:"password",
    default_verify:"pasword"
  };

  /**
  * We are using ui-router, so we need to deferIntercept to prevent
  * unwanted calls for templates.
  */
  beforeEach(module(function($urlRouterProvider) {
    $urlRouterProvider.deferIntercept();
  }));

  beforeEach(inject(function($injector) {
    $scope = $injector.get('$rootScope').$new();
    $httpBackend = $injector.get('$httpBackend');
    $state = $injector.get('$state');
    $q = $injector.get('$q');
    $urlRouter = $injector.get('$urlRouter');
    MiQNotificationService = $injector.get('MiQNotificationService');
    var injectedCtrl = $injector.get('$controller');
    $controller = injectedCtrl('miqNewProviderController');
  }));

  beforeEach(function(done){
    $httpBackend.when('GET', '//list_providers_settings').respond(200, {});
    $httpBackend.when('GET', '//types').respond(200, mock_types);
    var dataLoading = $controller.loadData();
    $q.all([dataLoading]).then(function() {
      done();
    });
    $httpBackend.flush();
  });

  it('Check if new_provider.hawkular state has enough views', function() {
    var newHawkular = $state.get('new_provider.hawkular');
    expect(newHawkular.views.hasOwnProperty('basic_information'))
      .toBeTruthy();
    expect(newHawkular.views.hasOwnProperty('detail_info'))
      .toBeTruthy();
  });
});
