describe('cloudTopologyController', function() {
    var scope, $controller, $httpBackend;
    var mock_data =  getJSONFixture('cloud_topology_response.json');
    var cloud_tenant = { id:"396086e5-7b0d-11e5-8286-18037327aaeb",  item:{display_kind:"CloudTenant", name:"admin", kind:"CloudTenant", id:"396086e5-7b0d-11e5-8286-18037327aaeb", miq_id:"100012"}};
    var cloud_provider = { id:"4",  item:{display_kind:"Openstack", name:"myProvider", kind:"CloudManager", id:"2", miq_id:"2"}};

    beforeEach(module('cloudTopologyApp'));

    beforeEach(inject(function(_$httpBackend_, $rootScope, _$controller_, $location) {
      spyOn($location, 'absUrl').and.returnValue('/network_topology/show');
      scope = $rootScope.$new();

      $httpBackend = _$httpBackend_;
      $httpBackend.when('GET','/cloud_topology/data').respond(mock_data);
      $controller = _$controller_('cloudTopologyController',
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
        expect(Object.keys(scope.kinds).length).toBeGreaterThan(4);
        expect(scope.kinds["AvailabilityZone"]).toBeDefined();
        expect(scope.kinds["Vm"]).toBeDefined();
        expect(scope.kinds["CloudTenant"]).toBeDefined();
      });
    });

    describe('the topology gets correct icons', function() {
      it('in graph elements', function() {
        var d = { id:"2",  item:{display_kind:"Openstack", kind:"CloudManager", id:"2"}};
        expect($controller.getIcon(d)).toContain("/assets/svg/vendor-openstack");
        expect($controller.getIcon(cloud_provider)).toContain("/assets/svg/vendor-openstack");
        d = { id:"4",  item:{display_kind:"VM", kind:"Vm", id:"4"}};
        expect($controller.getIcon(d)).toEqual("\uE90f");
        expect($controller.getIcon(cloud_tenant)).toEqual("\uE904");
      });
    });

    describe('dimensions are returned correctly', function() {
      it('of all objects', function() {
        var d = { id:"2",  item:{display_kind:"Openstack", kind:"CloudManager", id:"2", miq_id:"37"}};
        expect($controller.getDimensions(d)).toEqual({ x: -20, y: -20, r: 28 });
        expect($controller.getDimensions(cloud_provider)).toEqual({ x: -20, y: -20, r: 28 });
        d = { id:"4",  item:{display_kind:"VM", kind:"Vm", id:"4", miq_id:"25"}};
        expect($controller.getDimensions(d)).toEqual({ x: 0, y: 9, r: 21 });
        expect($controller.getDimensions(cloud_tenant)).toEqual({ x: 0, y: 9, r: 19 });
      });
    });

});