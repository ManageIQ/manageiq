describe('Testing repositoryDataFactory - Promise', function(){
  var repositoryDataFactory,
    jsonResponse = [{"name":"abc", storage:{"name":"//aa/a"}}];

  beforeEach(function(){
    module('ManageIQ');
    inject(function($injector){
      repositoryDataFactory = $injector.get('repositoryDataFactory');
      API = $injector.get('API');
      API.get = jasmine.createSpy("get() spy").and.callFake(function() {
        return jsonResponse;
      });
    });
  });

  it('returns Repository data', function() {
    var data = repositoryDataFactory.getRepositoryData(12345);
    expect(data[0].name).toEqual('abc');
    expect(data[0].storage.name).toEqual('//aa/a');
  });
});
