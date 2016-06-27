describe('middlewareTopologyController', function () {
  var scope, $controller, $httpBackend;
  var mock_data = getJSONFixture('middleware_topology_response.json');

  var mw_manager = {
    id: "MiddlewareManager1", item: {
      "name": "localhost",
      "kind": "MiddlewareManager",
      "miq_id": 1,
      "status": "Unknown",
      "display_kind": "Hawkular",
      "icon": "vendor-hawkular"
    }
  };

  var mw_server = {
    id: "MiddlewareServer1", item: {
      "name": "Local",
      "kind": "MiddlewareServer",
      "miq_id": 1,
      "status": "Unknown",
      "display_kind": "MiddlewareServer",
      "icon": "vendor-wildfly"
    }
  };

  var mw_deployment = {
    id: "MiddlewareDeployment1",
    item: {
      "name": "hawkular-command-gateway-war.war",
      "kind": "MiddlewareDeployment",
      "miq_id": 1,
      "status": "Unknown",
      "display_kind": "MiddlewareDeploymentWar"
    }
  };

  var mw_datasource = {
    id: "MiddlewareDatasource1",
    item: {
      "name": "Datasource [ExampleDS]",
      "kind": "MiddlewareDatasource",
      "miq_id": 1,
      "status": "Unknown",
      "display_kind": "MiddlewareDatasource"
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
      expect(Object.keys(scope.kinds).length).toBe(4);
      expect(scope.kinds["MiddlewareManager"]).toBeDefined();
      expect(scope.kinds["MiddlewareServer"]).toBeDefined();
      expect(scope.kinds["MiddlewareDeployment"]).toBeDefined();
      expect(scope.kinds["MiddlewareDatasource"]).toBeDefined();
    });
  });


  describe('the mw topology gets correct icons', function () {
    it('in graph elements', function () {
      expect($controller.getIcon(mw_manager).icon).toContain("vendor-hawkular");
      expect($controller.getIcon(mw_server).icon).toContain("vendor-wildfly");
      expect($controller.getIcon(mw_deployment).fontfamily).toEqual("icomoon")
      expect($controller.getIcon(mw_datasource).fontfamily).toEqual("FontAwesome")
    });
  });

  describe('dimensions are returned correctly', function () {
    it('for all objects', function () {
      expect($controller.getCircleDimensions(mw_manager)).toEqual({x: -20, y: -20, height: 40, width: 40, r: 28});
      expect($controller.getCircleDimensions(mw_server)).toEqual({x: -12, y: -12, height: 23, width: 23, r: 19});
      expect($controller.getCircleDimensions(mw_deployment)).toEqual({x: -9, y: -9, height: 18, width: 18, r: 17});
      expect($controller.getCircleDimensions(mw_datasource)).toEqual({x: -9, y: -9, height: 18, width: 18, r: 17});
    });
  });

  describe('icon types are returned correctly', function () {
    it('for all objects', function () {
      expect($controller.getIcon(mw_manager).type).toEqual("image");
      expect($controller.getIcon(mw_server).type).toEqual("image");
      expect($controller.getIcon(mw_deployment).type).toEqual("glyph");
      expect($controller.getIcon(mw_datasource).type).toEqual("glyph");
    });
  });

});
