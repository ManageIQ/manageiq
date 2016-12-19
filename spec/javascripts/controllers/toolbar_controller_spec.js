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
     beforeEach(function(){
       $controller.initObject(JSON.stringify(middleware_toolbar_list));
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

     it('Each dataView should have url set', function() {
       $controller.dataViews.forEach(function(dataView) {
         expect(dataView.url !== '').toBeTruthy();
       })
     })

     it('Each button should have eventFunction set up', function() {
      _.chain($controller.toolbarItems)
        .flatten()
        .map(function(item) {
          return (item && item.hasOwnProperty('items')) ? item.items : item;
        })
        .flatten()
        .filter({type: 'button'})
        .each(function(item) {
          expect(item.hasOwnProperty('eventFunction')).toBeTruthy();
        })
     })
   })

   describe('show detail toolbar', function() {
     beforeEach(function(){
       $controller.initObject(JSON.stringify(middleware_toolbar_detail));
     });

     it('middleware server, it should be different than list toolbar', function() {
       expect(middleware_toolbar_list !== $controller.toolbarItems).toBeTruthy();
     });
   });

   describe('event data toolbar', function() {
     beforeEach(function() {
       spyOn($controller, 'onUpdateItem');
       $controller.initObject(JSON.stringify([[{id: 'someButton', hidden: false, type: 'button'}]]));
     })

     it('should call update toolbar', function() {
       sendDataWithRx({ update: 'someButton', type: 'hidden', value: true });
       expect($controller.onUpdateItem).toHaveBeenCalled();
     })
   });
});
