describe('reportDataController', function () {
  beforeEach(module('ManageIQ.gtl'));

  var $controller, $httpBackend, $scope;

  var report_data = getJSONFixture('report_data_response.json');

  var initObject = {
    modelName: 'manageiq%2Fproviders%2Finfra_manager%2Fvms',
    activeTree: 'vandt_tree',
    gtlType: 'grid',
    currId: '',
    sortColIdx: '0',
    sortDir: 'DESC',
    isExplorer: false,
    showUrl: 'some_url/show',
  }

  beforeEach(inject(function($injector) {
     $scope = $injector.get('$rootScope').$new();
     $httpBackend = $injector.get('$httpBackend');
     var injectedCtrl = $injector.get('$controller');
     $controller = injectedCtrl('reportDataController', {$scope: $scope});
   }));

  describe('receive data', function() {
    beforeEach(function() {
      $controller.MiQEndpointsService.rootPoint = '/mock_root';
      $httpBackend
        .whenGET("/mock_root/report_data?active_tree=vandt_tree&model=manageiq%252Fproviders%252Finfra_manager%252Fvms")
        .respond(report_data);
      $httpBackend
        .whenGET("/mock_root/report_data?active_tree=vandt_tree&model=manageiq%2Fproviders%2Finfra_manager%2Fvms")
        .respond(report_data);
    });

    it('Should set default values by init Object', function() {
      $controller.initObjects(initObject);
      expect($controller.gtlType).toBe(initObject.gtlType);
      expect($controller.settings.isLoading).toBeTruthy();
      expect(angular.equals($controller.initObject, initObject)).toBeTruthy();
    });


    it('should get data', function(done) {
      var settings = {isLoading: true};
      var result = $controller
          .getData(initObject.modelName, initObject.activeTree, initObject.currId, initObject.isExplorer, settings);
      result.then(function(data) {
        expect(angular.equals($controller.gtlData.cols, report_data.data.head)).toBeTruthy();
        expect(angular.equals($controller.gtlData.rows, report_data.data.rows)).toBeTruthy();
        expect(angular.equals($controller.settings, report_data.settings)).toBeTruthy();
        expect(angular.equals($controller.perPage.value, report_data.settings.perpage)).toBeTruthy();
        expect(angular.equals($controller.perPage.text, report_data.settings.perpage)).toBeTruthy();
        done();
      });
      $httpBackend.flush();
      $scope.$apply();
    });

    it('should init controller', function(done) {
      var result = $controller.initController(initObject);
      result.then(function() {
        expect($controller.settings.isLoading).toBeFalsy();
        expect(report_data.settings.sort_dir === "ASC").toBe($controller.settings.sortBy.isAscending);
        expect($controller.settings.sortBy.sortObject.col_idx).toBe(report_data.settings.sort_col);
        expect($controller.perPage.enabled).toBeTruthy();
        expect($controller.perPage.hidden).toBeFalsy();
        done();
      });
      $httpBackend.flush();
      $scope.$apply();
    });
  });

  describe('common functions', function() {
    beforeEach(function(done) {
      $controller.MiQEndpointsService.rootPoint = '/mock_root';
      $httpBackend
        .whenGET("/mock_root/report_data?active_tree=vandt_tree&model=manageiq%2Fproviders%2Finfra_manager%2Fvms")
        .respond(report_data);
      $httpBackend
        .whenGET("/mock_root/report_data?active_tree=vandt_tree&explorer=true&model=manageiq%2Fproviders%2Finfra_manager%2Fvms")
        .respond(report_data);
      $controller.initController(initObject).then(function() {
        done();
      });
      $httpBackend.flush();
      $scope.$apply();
    });

    it('should set correct sort', function() {
      var indexOfItem = 4;
      var isAscending = true;
      $controller.setSort(indexOfItem, isAscending);
      expect(
        angular.equals($controller.settings.sortBy.sortObject, $controller.gtlData.cols[indexOfItem])
      ).toBeTruthy();
      expect($controller.settings.sortBy.isAscending).toBe(isAscending);
    });

    it('should call fetch of new items after changing sort', function() {
      var indexOfItem = 5;
      var isAscending = false;
      spyOn($controller, 'initController');
      $controller.onSort(indexOfItem, isAscending);
      expect(
        angular.equals($controller.settings.sortBy.sortObject, $controller.gtlData.cols[indexOfItem])
      ).toBeTruthy();
      expect($controller.initController).toHaveBeenCalled();
    });

    it('should set data for paging', function() {
      var startIndex = 5;
      var perPage = 10;
      $controller.setPaging(startIndex, perPage);
      expect($controller.perPage.value).toBe(perPage);
      expect($controller.perPage.text).toBe(perPage);
      expect($controller.settings.perpage).toBe(perPage);
      expect($controller.settings.startIndex).toBe(startIndex);
      expect($controller.settings.current).toBe(( startIndex / perPage) + 1);
    });

    it('should call fetch of new data after setting paging', function() {
      var startIndex = 10;
      var perPage = 5;
      spyOn($controller, 'initController');
      spyOn($controller, 'setPaging');
      $controller.onLoadNext(startIndex, perPage);
      expect($controller.initController).toHaveBeenCalled();
      expect($controller.setPaging).toHaveBeenCalled();
    });

    it('should select item and call rowSelect', function() {
      var itemId = "10";
      var selected = true;
      spyOn(window, 'sendDataWithRx');
      $controller.onItemSelect({id: itemId}, selected);
      selectedItem = $controller.gtlData.rows.filter(function(item) {
        return item.id === itemId;
      });
      expect(selectedItem[0].checked).toBe(selected);
      expect(selectedItem[0].selected).toBe(selected);
      expect(window.sendDataWithRx).toHaveBeenCalledWith({rowSelect: selectedItem[0]});
      expect(ManageIQ.gridChecks.indexOf(itemId) !== -1).toBeTruthy();
    });

    it('should deselect item and call rowSelect', function() {
      var itemId = "10";
      var selected = false;
      spyOn(window, 'sendDataWithRx');
      $controller.onItemSelect({id: itemId}, selected);
      selectedItem = $controller.gtlData.rows.filter(function(item) {
        return item.id === itemId;
      });
      expect(selectedItem[0].checked).toBe(selected);
      expect(selectedItem[0].selected).toBe(selected);
      expect(window.sendDataWithRx).toHaveBeenCalledWith({rowSelect: selectedItem[0]});
      expect(ManageIQ.gridChecks.indexOf(itemId) === -1).toBeTruthy();
    });

    it('should create POST redirect for explorer', function() {
      var itemId = "10";
      var clickEvent = $.Event('click');
      initObject.isExplorer = true;
      spyOn(clickEvent, 'stopPropagation');
      spyOn(clickEvent, 'preventDefault');
      selectedItem = $controller.gtlData.rows.filter(function(item) {
        return item.id === itemId;
      });
      $controller.onItemClicked(selectedItem[0], clickEvent);
      expect(clickEvent.stopPropagation).toHaveBeenCalled();
      expect(clickEvent.preventDefault).toHaveBeenCalled();
    });

    it('should create redirect for non explorer click on item', function() {
      var itemId = "10";
      var clickEvent = $.Event('click');
      initObject.isExplorer = false;
      spyOn(clickEvent, 'stopPropagation');
      spyOn(clickEvent, 'preventDefault');
      spyOn(window, 'DoNav');
      selectedItem = $controller.gtlData.rows.filter(function(item) {
        return item.id === itemId;
      });
      $controller.onItemClicked(selectedItem[0], clickEvent);
      expect(window.DoNav).toHaveBeenCalledWith(initObject.showUrl + '/' + selectedItem[0].id);
      expect(clickEvent.stopPropagation).toHaveBeenCalled();
      expect(clickEvent.preventDefault).toHaveBeenCalled();
    });
  });
});
