describe('toolbarController', function () {
  beforeEach(module('ManageIQ.toolbar'));

  var middleware_toolbar_list = getJSONFixture('toolbar_middleware_server_list.json');
  var middleware_toolbar_detail = getJSONFixture('toolbar_middleware_server_detail.json');

  var responseData;
  var $controller, $httpBackend, $scope, $q;

  beforeEach(inject(function($injector) {
     $q = $injector.get('$q')
     $scope = $injector.get('$rootScope').$new();
     $httpBackend = $injector.get('$httpBackend');
     var injectedCtrl = $injector.get('$controller');
     $controller = injectedCtrl('miqToolbarController', {$scope: $scope});
   }));

   describe('show list toolbar', function() {
     beforeEach(function(done){
       $httpBackend.when('GET', '//toolbar_settings?is_list=true').respond(200, middleware_toolbar_list);
       $controller.isList = true;
       var dataLoading = $controller.init();
       $q.all([dataLoading]).then(function(data) {
         done();
       });
       $httpBackend.flush();
     });

     it('toolbar data loaded, toolbar items more than one, 3 toolbar items contain {url_parms: "main_div"}', function() {
       var allItems = _
                        .chain($controller.toolbarItems)
                        .flatten()
                        .map('items')
                        .flatten()
                        .value();

       expect($controller.toolbarItems.length > 0).toBeTruthy();
       expect(_.filter(allItems, {url_parms: 'main_div'}).length >= 3).toBeTruthy();
     });

     it('check one row and observe if toolbar items gets enabled', function() {
       var inputCheckbox = document.createElement('input')
       inputCheckbox.setAttribute('type', 'checkbox');
       inputCheckbox.setAttribute('checked', true);
       sendDataWithRx({rowSelect: inputCheckbox});
       var allItems = _
                        .chain($controller.toolbarItems)
                        .flatten()
                        .map('items')
                        .flatten()
                        .value();
      expect(_.filter(allItems, {enabled: true}).length >= 3).toBeTruthy();
     });
   })

   describe('show detail toolbar', function() {
     it('middleware server, it should be different than list toolbar', function(done) {
       $httpBackend.when('GET', '//toolbar_settings?is_list=false').respond(200, middleware_toolbar_list);
       $controller.isList = false;
       var listToolbar = $controller.toolbarItems;
       var dataLoading = $controller.init();
       $q.all([dataLoading]).then(function(data) {
         expect(listToolbar !== $controller.toolbarItems).toBeTruthy();
         done();
       });
       $httpBackend.flush();
     });
   });

});
