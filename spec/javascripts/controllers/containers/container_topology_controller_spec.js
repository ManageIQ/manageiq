describe('containerTopologyController', function() {
    var scope, $controller, $httpBackend;
    var mock_data =  getJSONFixture('container_topology_response.json');
    var replicator = { id:"396086e5-7b0d-11e5-8286-18037327aaeb",  item:{display_kind:"Replicator", kind:"ContainerReplicator", id:"396086e5-7b0d-11e5-8286-18037327aaeb", miq_id:"10"}};

    beforeEach(module('topologyApp'));

    beforeEach(inject(function(_$httpBackend_, $rootScope, _$controller_, $location) {
      spyOn($location, 'absUrl').and.returnValue('/container_topology/show');
      scope = $rootScope.$new();

      $httpBackend = _$httpBackend_;
      $httpBackend.when('GET','/container_topology/data').respond(mock_data);
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
      });
    });

    describe('the topology gets correct icons', function() {
      it('in graph elements', function() {
        var d = { id:"2",  item:{display_kind:"Openshift", kind:"ContainerManager", id:"2"}};
        expect($controller.getIcon(d)).toEqual("\uE626");
        d = { id:"3",  item:{display_kind:"Pod", kind:"ContainerGroup", id:"3"}};
        expect($controller.getIcon(d)).toEqual("\uF1B3");
        d = { id:"4",  item:{display_kind:"VM", kind:"Vm", id:"4"}};
        expect($controller.getIcon(d)).toEqual("\uE600");
        expect($controller.getIcon(replicator)).toEqual("\uE624");
      });
    });

    describe('the dbl click gets correct navigation', function() {
      it('to entity pages', function() {
        var d = { id:"2",  item:{display_kind:"Openshift", kind:"ContainerManager", id:"2", miq_id:"37"}};
        expect($controller.dblclick(d)).toEqual("/ems_container/show/37");
        d = { id:"3",  item:{display_kind:"Pod", kind:"ContainerGroup", id:"3", miq_id:"30"}};
        expect($controller.dblclick(d)).toEqual("/container_group/show/30");
        d = { id:"4",  item:{display_kind:"VM", kind:"Vm", id:"4", miq_id:"25"}};
        expect($controller.dblclick(d)).toEqual("/vm/show/25");
        expect($controller.dblclick(replicator)).toEqual("/container_replicator/show/10");
      });
    });

    describe('dimensions are returned correctly', function() {
      it('of all objects', function() {
        var d = { id:"2",  item:{display_kind:"Openshift", kind:"ContainerManager", id:"2", miq_id:"37"}};
        expect($controller.getDimensions(d)).toEqual({ x: 0, y: 16, r: 28 });
        d = { id:"3",  item:{display_kind:"Pod", kind:"ContainerGroup", id:"3", miq_id:"30"}};
        expect($controller.getDimensions(d)).toEqual({ x: 1, y: 6, r: 17 });
        d = { id:"4",  item:{display_kind:"VM", kind:"Vm", id:"4", miq_id:"25"}};
        expect($controller.getDimensions(d)).toEqual({ x: 0, y: 9, r: 21 });
        expect($controller.getDimensions(replicator)).toEqual({ x: 0, y: 9, r: 17 });
      });
    });

    describe('tooltips have correct content', function() {
      it('of all objects', function() {
        var d = { id:"2",  item:{display_kind:"Openshift", kind:"ContainerManager", id:"2", miq_id:"37", status: "Unreachable", name:"molecule"}};
        expect($controller.tooltip(d)).toEqual([ 'Name: molecule', 'Type: Openshift', 'Status: Unreachable' ] );
        d = { id:"3",  item:{display_kind:"Pod", kind:"ContainerGroup", id:"3", miq_id:"30", status: "Running", name:"mypod"}};
        expect($controller.tooltip(d)).toEqual([ 'Name: mypod', 'Type: Pod', 'Status: Running' ] );
        d = { id:"4",  item:{display_kind:"VM", kind:"Vm", id:"4", miq_id:"25", status: "On", name:"vm123", provider: "myrhevprovider"}};
        expect($controller.tooltip(d)).toEqual([ 'Name: vm123', 'Type: VM', 'Status: On', 'Provider: myrhevprovider' ]);
      });
    });
    
});
