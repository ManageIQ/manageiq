ManageIQ.angular.app.factory('repositoryDataFactory', ['API', function(API) {
    var factoryRepository = {
      getRepositoryData: function(id) {
        if(angular.isDefined(id)) {
          return API.get('/api/repositories/' + id + '?expand=resources&attributes=storage')
        }
      }
    };
    return factoryRepository;
}]);


