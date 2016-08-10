describe('Testing serviceDataFactory - Promise', function(){
  var serviceDataFactory,
  jsonResponse = [{"name":"abc", description:"service_description"}];
  beforeEach(function(){
    module('ManageIQ');
    inject(function($injector){
      serviceDataFactory = $injector.get('serviceDataFactory');
      API = $injector.get('API');
      API.get = jasmine.createSpy("get() spy").and.callFake(function() {
        return {
          then: function(callback) {return jsonResponse;}
        };
      });
    });
  });

  it('returns Service data', function() {
    var data = serviceDataFactory.getServiceData(12345);
    expect(data[0].name).toEqual('abc');
    expect(data[0].description).toEqual('service_description');
    });
});

