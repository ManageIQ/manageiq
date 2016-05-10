describe('middleware.providers.miqNewProviderController', function() {
  beforeEach(module('middleware.provider'));

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

  it('validation of valid object should show success alert', function(){
    $httpBackend.when('POST', '/ems_middleware/validate_provider')
                .respond(200, {
                  result: true,
                  details: "",
                  ems_object: validObject
                });
    spyOn($controller, 'stripProtocol');
    spyOn($controller, 'validateFunction');

    validateObject(validObject);

    expect($controller.stripProtocol)
      .toHaveBeenCalled();
    expect($controller.validateFunction)
      .toHaveBeenCalled();
  });

  it('save of valid object should be saved', function(){
    $httpBackend.when('POST', '/ems_middleware/new_provider')
                .respond(200, {
                  result: true,
                  details: "",
                  ems_object: validObject
                });
    spyOn($controller, 'stripProtocol');
    spyOn($controller, 'saveObject');

    saveObject(validObject);

    expect($controller.stripProtocol)
      .toHaveBeenCalled();
    expect($controller.saveObject)
      .toHaveBeenCalled();
  });

  it('Check if new_provider.hawkular state has enough views', function() {
    var newHawkular = $state.get('new_provider.hawkular');
    expect(newHawkular.views.hasOwnProperty('basic_information'))
      .toBeTruthy();
    expect(newHawkular.views.hasOwnProperty('detail_info'))
      .toBeTruthy();
  });

  it('Check if new_provider state has controller', function() {
    expect($state.get('new_provider').hasOwnProperty('controller'))
      .toBeTruthy();
  });

  function validateObject(objectForValidation) {
    $controller.newProvider = objectForValidation;
    $controller.validateAction();
    $httpBackend.flush();
    $scope.$digest();
  }

  function saveObject(objectForValidation) {
    $controller.newProvider = objectForValidation;
    $controller.saveAction();
    $httpBackend.flush();
    $scope.$digest();
  }


  function dumpStringify(rawObject) {
    console.log(JSON.stringify(rawObject));
  }
});
