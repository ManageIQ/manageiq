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

  var vm = {
    id: "Vm1",
    item: {
      "name": "Vm",
      "kind": "Vm",
      "miq_id": 1,
      "status": "Unknown",
      "display_kind": "Vm"
    }
  };

  var mw_domain = {
    id: "MiddlewareDomain1",
    item: {
      "name": "master",
      "kind": "MiddlewareDomain",
      "miq_id": 1,
      "status": "Unknown",
      "display_kind": "MiddlewareDomain"
    }
  };

  var mw_server_group = {
    id: "MiddlewareServerGroup1",
    item: {
      "name": "main-server-group",
      "kind": "MiddlewareServerGroup",
      "miq_id": 1,
      "status": "Unknown",
      "display_kind": "MiddlewareServerGroup"
    }
  };

  var mw_messaging = {
    id: "MiddlewareMessaging1",
    item: {
      "name": "JMS Topic [HawkularMetricData]",
      "kind": "MiddlewareMessaging",
      "miq_id": 1,
      "status": "Unknown",
      "display_kind": "MiddlewareMessaging"
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
      expect(Object.keys(scope.kinds).length).toBe(8);
      expect(scope.kinds["MiddlewareManager"]).toBeDefined();
      expect(scope.kinds["MiddlewareServer"]).toBeDefined();
      expect(scope.kinds["MiddlewareDeployment"]).toBeDefined();
      expect(scope.kinds["MiddlewareDatasource"]).toBeDefined();
      expect(scope.kinds["Vm"]).toBeDefined();
      expect(scope.kinds["MiddlewareDomain"]).toBeDefined();
      expect(scope.kinds["MiddlewareServerGroup"]).toBeDefined();
      expect(scope.kinds["MiddlewareMessaging"]).toBeDefined();
    });
  });


  describe('the mw topology gets correct icons', function () {
    it('in graph elements', function () {
      expect($controller.getIcon(mw_manager).icon).toContain("vendor-hawkular");
      expect($controller.getIcon(mw_server).icon).toContain("vendor-wildfly");
      expect($controller.getIcon(mw_deployment).fontfamily).toEqual("icomoon");
      expect($controller.getIcon(mw_datasource).fontfamily).toEqual("FontAwesome");
      expect($controller.getIcon(vm).fontfamily).toEqual("PatternFlyIcons-webfont");
      expect($controller.getIcon(mw_domain).fontfamily).toEqual("FontAwesome");
      expect($controller.getIcon(mw_server_group).fontfamily).toEqual("FontAwesome");
      expect($controller.getIcon(mw_messaging).fontfamily).toEqual("FontAwesome");
    });
  });

  describe('dimensions are returned correctly', function () {
    it('for all objects', function () {
      expect($controller.getCircleDimensions(mw_manager)).toEqual({x: -20, y: -20, height: 40, width: 40, r: 28});
      expect($controller.getCircleDimensions(mw_server)).toEqual({x: -12, y: -12, height: 23, width: 23, r: 19});
      expect($controller.getCircleDimensions(mw_deployment)).toEqual({x: -9, y: -9, height: 18, width: 18, r: 17});
      expect($controller.getCircleDimensions(mw_datasource)).toEqual({x: -9, y: -9, height: 18, width: 18, r: 17});
      expect($controller.getCircleDimensions(vm)).toEqual({ x: 0, y: 9, height: 40, width: 40, r: 21 });
      expect($controller.getCircleDimensions(mw_domain)).toEqual({x: -9, y: -9, height: 18, width: 18, r: 17});
      expect($controller.getCircleDimensions(mw_server_group)).toEqual({x: -9, y: -9, height: 18, width: 18, r: 17});
      expect($controller.getCircleDimensions(mw_messaging)).toEqual({x: -9, y: -9, height: 18, width: 18, r: 17});
    });
  });

  describe('icon types are returned correctly', function () {
    it('for all objects', function () {
      expect($controller.getIcon(mw_manager).type).toEqual("image");
      expect($controller.getIcon(mw_server).type).toEqual("image");
      expect($controller.getIcon(mw_deployment).type).toEqual("glyph");
      expect($controller.getIcon(mw_datasource).type).toEqual("glyph");
      expect($controller.getIcon(vm).type).toEqual("glyph");
      expect($controller.getIcon(mw_domain).type).toEqual("glyph");
      expect($controller.getIcon(mw_server_group).type).toEqual("glyph");
      expect($controller.getIcon(mw_messaging).type).toEqual("glyph");
    });
  });

});
