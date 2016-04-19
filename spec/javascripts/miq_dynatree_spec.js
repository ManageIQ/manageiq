describe('miq_dynatree', function() {
  describe('hoverNodeId', function() {
    beforeEach(function(){
        spyOn(window, "miqDomElementExists").and.returnValue(true)
    });

    it('can handle compressed id', function() {
      expect(hoverNodeId("h_sw-10r42_l-10r66_v-10r1238")).toEqual('v-10000000001238');
    });

    it('can handle full id', function() {
      expect(hoverNodeId("h_sw-10r42_l-10r66_v-10000000001238")).toEqual('v-10000000001238');
    });
  });
});
