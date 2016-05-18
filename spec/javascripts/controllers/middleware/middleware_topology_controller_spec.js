describe('middlewareTopologyController', function () {
  var scope, $controller, $httpBackend;
  var mock_data = getJSONFixture('middleware_topology_response.json');

  var mw_manager = {
    id: "1", item: {
      "name": "Hawkular",
      "kind": "MiddlewareManager",
      "miq_id": 1,
      "status": "Unknown",
      "display_kind": "Hawkular",
      "icon": "vendor-hawkular",
      "id": "1"
    }
  };

  var mw_server = {
    id: "/t;28026b36-8fe4-4332-84c8-524e173a68bf/f;91044f79-156e-4076-8056-ac3ac44ffff9/r;Local~~", item: {
      "name": "Local",
      "kind": "MiddlewareServer",
      "miq_id": 4,
      "status": "Unknown",
      "display_kind": "MiddlewareServer",
      "icon": "vendor-hawkular",
      "id": "Local~~"
    }
  };

  var mw_deployment = {
    id: "/t;28026b36-8fe4-4332-84c8-524e173a68bf/f;91044f79-156e-4076-8056-ac3ac44ffff9/r;Local~~/r;Local~%2Fdeployment%3Dhawkular-command-gateway-war.war",
    item: {
      "name": "hawkular-command-gateway-war.war",
      "kind": "MiddlewareDeployment",
      "miq_id": 49,
      "status": "Unknown",
      "display_kind": "MiddlewareDeployment",
      "icon": "middleware_deployment_war",
      "id": "Local~/deployment=hawkular-command-gateway-war.war"
    }
  };

  beforeEach(module('mwTopologyApp'));

  beforeEach(inject(function (_$httpBackend_, $rootScope, _$controller_, $location) {
    spyOn($location, 'absUrl').and.returnValue('/middleware_topology/show');
    scope = $rootScope.$new();

    $httpBackend = _$httpBackend_;
    $httpBackend.when('GET', '/middleware_topology/data').respond(mock_data);
    $controller = _$controller_('middlewareTopologyController',
      {$scope: scope});
    $httpBackend.flush();
  }));

  afterEach(function () {
    $httpBackend.verifyNoOutstandingExpectation();
    $httpBackend.verifyNoOutstandingRequest();
  });

  describe('mw topology data loads successfully', function () {
    it('in all main objects', function () {
      expect(scope.items).toBeDefined();
      expect(scope.relations).toBeDefined();
      expect(scope.kinds).toBeDefined();
    });
  });

  describe('kinds contains all expected mw kinds', function () {
    it('in all main objects', function () {
      expect(Object.keys(scope.kinds).length).toBe(3);
      expect(scope.kinds["MiddlewareManager"]).toBeDefined();
      expect(scope.kinds["MiddlewareServer"]).toBeDefined();
      expect(scope.kinds["MiddlewareDeployment"]).toBeDefined();
    });
  });

  describe('the mw topology gets correct icons', function () {
    it('in graph elements', function () {
      expect($controller.class_name(mw_manager)).toContain("vendor-hawkular");
      expect($controller.class_name(mw_server)).toContain("vendor-hawkular");
      expect($controller.class_name(mw_deployment)).toContain("middleware_deployment_war");
    });
  });

  describe('dimensions are returned correctly', function () {
    it('for all objects', function () {
      expect($controller.getDimensions(mw_manager)).toEqual({x: -20, y: -20, height: 40, width: 40, r: 28});
      expect($controller.getDimensions(mw_server)).toEqual({x: -12, y: -12, height: 23, width: 23, r: 19});
      expect($controller.getDimensions(mw_deployment)).toEqual({x: -9, y: -9, height: 18, width: 18, r: 17});
    });
  });

});
