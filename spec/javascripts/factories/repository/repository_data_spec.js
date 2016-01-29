describe('Testing repositoryDataFactory - Promise', function(){
  var repositoryDataFactory,
    $httpBackend,
    jsonResponse = [{"repo_name":"abc", "repo_path":"//aa/a"}];

  beforeEach(function(){
    module('ManageIQ.angularApplication');
    inject(function($injector){
      repositoryDataFactory = $injector.get('repositoryDataFactory');
      $httpBackend = $injector.get('$httpBackend');
      $httpBackend.whenGET('/repository/repository_form_fields/12345')
        .respond( jsonResponse );
    });
  });

  it('returns Repository data', function(done) {
    var promise = repositoryDataFactory.getRepositoryData(12345);
    promise.then(function(data){
      expect(data.data[0].repo_name).toEqual('abc');
      expect(data.data[0].repo_path).toEqual('//aa/a');
      expect(data.data.length).toEqual(1);
      done();
    });
    $httpBackend.flush();
  });
});
