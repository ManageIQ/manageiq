describe('middleware.providers.miqListProvidersController', function() {
  beforeEach(module('miq.provider'));

  var mock_data = getJSONFixture('middleware/list_providers.json');
  var mock_toolbar_settings = getJSONFixture('middleware/toolbar_settings.json');

  var responseData;
  var $controller, $httpBackend, $scope, $q;

  /**
  * We are using ui-router, so we need to deferIntercept to prevent
  * unwanted calls for templates.
  */
  beforeEach(module(function($urlRouterProvider) {
    $urlRouterProvider.deferIntercept();
  }));

  beforeEach(inject(function($injector) {
     $q = $injector.get('$q')
     $scope = $injector.get('$rootScope').$new();
     $httpBackend = $injector.get('$httpBackend');
     var injectedCtrl = $injector.get('$controller');
     $controller = injectedCtrl('miqListProvidersController', {$scope: $scope});
   }));

   beforeEach(function(done){
     $httpBackend.when('GET', '//list_providers_settings').respond(200, {});
     $httpBackend.when('GET', '//toolbar_settings?is_list=true').respond(200, mock_toolbar_settings);
     $httpBackend.when('GET', '//list_providers').respond(200, mock_data);
     var dataLoading = $controller.loadData();
     $q.all([dataLoading]).then(function() {
       done();
     });
     $httpBackend.flush();
     $scope.$digest();
   });

  it('check retrieved data (rows and cols) and their structure (each row should have id, icon and nameItem) based on mocked data.',
  function(){
    expect($controller.columnsToShow.length > 0).toBeTruthy();
    expect($controller.data.length > 0).toBeTruthy();
    expect($controller.data[0].hasOwnProperty('id')).toBeTruthy();
    expect($controller.data[0].hasOwnProperty('icon')).toBeTruthy();
    expect($controller.data[0].hasOwnProperty('nameItem')).toBeTruthy();
  });

  it('select first row and check visibility of toolbar items', function(){
    $controller.data[0].selecteItem(true);
    expect($controller.data[0].selected).toBe(true);
    $controller.onRowSelected();
    _.each($controller.toolbarItems[0], function(toolbarItem){
      if (toolbarItem.hasOwnProperty('enabled')) {
        expect(toolbarItem.enabled).toBe(true);
      }
      _.each(toolbarItem.items, function(oneChild){
        if (oneChild.hasOwnProperty('enabled')) {
          expect(oneChild.enabled).toBe(true);
        }
      });
    });
  });

  it('unselect first row and check toolbar items to be disabled', function(){
    $controller.data[0].selecteItem(true);
    $controller.data[0].selecteItem(false);
    $controller.onRowSelected();
    _.each($controller.toolbarItems[0], function(toolbarItem){
      _.each(toolbarItem.items, function(oneChild){
        if (oneChild.hasOwnProperty('enabled') && oneChild.child_id != 'ems_middleware_new') {
          expect(oneChild.enabled).toBe(false);
        }
      });
    });
  });

  it('select 2 items and check if edit items is disabled', function(){
    $controller.data[0].selecteItem(true);
    $controller.data[1].selecteItem(true);
    var edit_provider = _.find($controller.toolbarItems[0][0].items, {child_id: 'ems_middleware_edit'});
    expect(edit_provider.enabled).toBe(false);
  });

  it('set 5 records per page and check number of visible items', function() {
    $controller.onPerPage({title: '5', value: 5});
    expect($controller.perPage.title === '5').toBeTruthy();
    expect($controller.MiQDataTableService.visibleItems.length).toBe(5);
  });

  it('load more items and check number of visible items', function() {
    $controller.MiQDataTableService.loadMore();
    expect($controller.MiQDataTableService.visibleItems.length > 5).toBeTruthy();
  });
});
