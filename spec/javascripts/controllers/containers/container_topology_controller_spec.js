describe('containerTopologyController', function() {
    var scope, $controller, $httpBackend;
    var mock_data =  getJSONFixture('container_topology_response.json');
    var replicator = { id:"396086e5-7b0d-11e5-8286-18037327aaeb",  item:{display_kind:"Replicator", name:"replicator1", kind:"ContainerReplicator", id:"396086e5-7b0d-11e5-8286-18037327aaeb", miq_id:"10"}};
    var openshift = { id:"2",  item:{display_kind:"Openshift", kind:"ContainerManager", id:"2", miq_id:"37"}};
    var vm = { id:"4",  item:{display_kind:"VM", kind:"Vm", id:"4", miq_id:"25"}};
    var pod = { id:"3",  item:{display_kind:"Pod", kind:"ContainerGroup", id:"3"}};

    beforeEach(module('topologyApp'));

    beforeEach(function() {
      var $window = {location: { pathname: '/ems_container/1' }};

      module(function($provide) {
        $provide.value('$window', $window);
      });
    });

    beforeEach(inject(function(_$httpBackend_, $rootScope, _$controller_, $window) {
      scope = $rootScope.$new();

      $httpBackend = _$httpBackend_;
      $httpBackend.when('GET','/container_topology/data/1').respond(mock_data);
      $controller = _$controller_('containerTopologyController',
          {$scope: scope});
      $httpBackend.flush();
    }));

    afterEach(function() {
      $httpBackend.verifyNoOutstandingExpectation();
      $httpBackend.verifyNoOutstandingRequest();
    });

    describe('data loads successfully', function() {
      it('in all main objects', function() {
        expect(scope.items).toBeDefined();
        expect(scope.relations).toBeDefined();
        expect(scope.kinds).toBeDefined();
      });
    });

    describe('kinds contain all expected kinds', function() {
      it('in all main objects', function() {
        expect(Object.keys(scope.kinds).length).toBeGreaterThan(7);
        expect(scope.kinds["Container"]).toBeDefined();
        expect(scope.kinds["Pod"]).toBeDefined();
        expect(scope.kinds["Node"]).toBeDefined();
        expect(scope.kinds["Route"]).toBeDefined();
      });
    });

    describe('the topology gets correct icons', function() {
      it('in graph elements', function() {
        expect($controller.getIcon(openshift).icon).toContain("/assets/svg/vendor-openshift");
        expect($controller.getIcon(openshift).type).toEqual("image");
        expect($controller.getIcon(pod).icon).toEqual("\uF1B3");
        expect($controller.getIcon(pod).type).toEqual("glyph");
        expect($controller.getIcon(vm).icon).toEqual("\uE90f");
        expect($controller.getIcon(replicator).icon).toEqual("\uE624");
      });
    });

    describe('dimensions are returned correctly', function() {
      it('of all objects', function() {
        expect($controller.getDimensions(openshift)).toEqual({ x: -20, y: -20, r: 28 });
        expect($controller.getDimensions(pod)).toEqual({ x: 1, y: 6, r: 17 });
        expect($controller.getDimensions(vm)).toEqual({ x: 0, y: 9, r: 21 });
        expect($controller.getDimensions(replicator)).toEqual({ x: -1, y: 8, r: 17 });
      });
    });
});
