describe('topologyService', function() {
    var testService;
    var replicator = { id:"396086e5-7b0d-11e5-8286-18037327aaeb",  item:{display_kind:"Replicator", kind:"ContainerReplicator", id:"396086e5-7b0d-11e5-8286-18037327aaeb", miq_id:"10"}};
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

    beforeEach(module('ManageIQ'));

    beforeEach(inject(function(topologyService) {
      testService = topologyService;
    }));

    describe('tooltips have correct content', function() {
      it('of all objects', function() {
        var d = { id:"2",  item:{display_kind:"Openshift", kind:"ContainerManager", id:"2", miq_id:"37", status: "Unreachable", name:"molecule"}};
        expect(testService.tooltip(d)).toEqual([ 'Name: molecule', 'Type: Openshift', 'Status: Unreachable' ] );
        d = { id:"3",  item:{display_kind:"Pod", kind:"ContainerGroup", id:"3", miq_id:"30", status: "Running", name:"mypod"}};
        expect(testService.tooltip(d)).toEqual([ 'Name: mypod', 'Type: Pod', 'Status: Running' ] );
        d = { id:"4",  item:{display_kind:"VM", kind:"Vm", id:"4", miq_id:"25", status: "On", name:"vm123", provider: "myrhevprovider"}};
        expect(testService.tooltip(d)).toEqual([ 'Name: vm123', 'Type: VM', 'Status: On', 'Provider: myrhevprovider' ]);
      });
    });

    describe('the dbl click gets correct navigation url', function() {
      it('to entity pages', function() {
        var d = { id:"2",  item:{display_kind:"Openshift", kind:"ContainerManager", id:"2", miq_id:"37"}};
        expect(testService.geturl(d)).toEqual("/ems_container/37");
        expect(testService.geturl(mw_manager)).toEqual("/ems_middleware/1");
        d = { id:"3",  item:{display_kind:"Pod", kind:"ContainerGroup", id:"3", miq_id:"30"}};
        expect(testService.geturl(d)).toEqual("/container_group/show/30");
        d = { id:"4",  item:{display_kind:"VM", kind:"Vm", id:"4", miq_id:"25"}};
        expect(testService.geturl(d)).toEqual("/vm/show/25");
        expect(testService.geturl(replicator)).toEqual("/container_replicator/show/10");
      });
    });

});
