(function(){
  var COTNROLLER_NAME = 'reportDataController';

  /**
  * Private method for setting rootPoint of MiQEndpointsService.
  * @param MiQEndpointsService service responsible for endpoits.
  */
  function initEndpoints(MiQEndpointsService) {
    MiQEndpointsService.rootPoint = '/' + ManageIQ.controller;
    MiQEndpointsService.endpoints.listDataTable = '/' + ManageIQ.constants.gtlList;
  }

  /**
  * Method for init paging component for GTL.
  * Default paging has 5, 10, 20, 50, 100, 1000
  */
  function defaultPaging() {
    return {
      label: __('Items per page'),
      enabled: true,
      text: 10,
      value: 10,
      hidden: false,
      items: [
        {id: 'per_page_5', text: 5, value: 5, hidden: false, enabled: true},
        {id: 'per_page_10', text: 10, value: 10, hidden: false, enabled: true},
        {id: 'per_page_20', text: 20, value: 20, hidden: false, enabled: true},
        {id: 'per_page_50', text: 50, value: 50, hidden: false, enabled: true},
        {id: 'per_page_100', text: 100, value: 100, hidden: false, enabled: true},
        {id: 'per_page_1000', text: 1000, value: 1000, hidden: false, enabled: true}
      ]
    };
  }

  /**
  * Private method for subscribing to rxSubject.
  * For success functuon @see ToolbarController#onRowSelect()
  */
  function subscribeToSubject() {
    this.subscription = ManageIQ.angular.rxSubject.subscribe(function(event) {
      if (event.initController && event.initController.name === COTNROLLER_NAME) {
        this.initController(event.initController.data);
      } else if (event.unsubscribe && event.unsubscribe === COTNROLLER_NAME) {
        this.onUnsubscribe();
      } else if (event.tollbarEvent && (event.tollbarEvent === 'itemClicked')) {
        this.setSandPaperClass();
      }
    }.bind(this),
    function (err) {
      console.error('Angular RxJs Error: ', err);
    },
    function () {
      console.debug('Angular RxJs subject completed, no more events to catch.');
    });
  }

  /**
  * Constructor for GTL controller. This constructor will init params accessible via `this` property and calls
  * initEndpoints, subscribes to subject, and sets default paging.
  * @param MiQDataTableService datatable service for fetching GTL data and filtering them.
  * @param MiQEndpointsService service for setting basic routes.
  * @param $filter angular filter Service.
  */
  var ReportDataController = function(MiQDataTableService, MiQEndpointsService, $filter, $location, $scope) {
    this.settings = {};
    this.MiQDataTableService = MiQDataTableService;
    this.MiQEndpointsService = MiQEndpointsService;
    this.$filter = $filter;
    this.$scope = $scope;
    this.$location = $location;
    initEndpoints(this.MiQEndpointsService);
    subscribeToSubject.bind(this)();
    this.perPage = defaultPaging();
  }

  ReportDataController.prototype.setSort = function(headerId, isAscending) {
    if (this.gtlData.cols[headerId]) {
      this.settings.sortBy = {
        sortObject: this.gtlData.cols[headerId],
        isAscending: isAscending
      };
    }
  }

  ReportDataController.prototype.onUnsubscribe = function() {
    this.subscription.dispose();
  }

  /**
  * Method for handeling sort function. This will be called when sort of items will be needed. This method will set
  * sort object to settings and calls method for filtering and sorting.
  * @param headerId ID of column which is sorted by.
  * @param isAscending true | false.
  */
  ReportDataController.prototype.onSort = function(headerId, isAscending) {
    this.setSort(headerId, isAscending);
    this.initController(this.initObject);
  }

  ReportDataController.prototype.setPaging = function(start, perPage) {
    this.perPage.value = perPage;
    this.perPage.text = perPage;
    this.settings.perpage = perPage;
    this.settings.startIndex = start;
    this.settings.current = ( start / perPage) + 1;
  }

  /**
  * Method for loading more items, either by selecting next page, or by choosing different number of items per page.
  * It will calculate start index of page and will call method for filtering and sorting items.
  * @param start index of item, which will be taken as start item.
  * @param perPage Number of items per page.
  */
  ReportDataController.prototype.onLoadNext = function(start, perPage) {
    this.setPaging(start, perPage);
    this.initController(this.initObject);
  }

  /**
  * Method for handeling clicking on item (either gliphicon or item). It will perform navigation or post message based
  * on type of items.
  * @param item which item was clicked.
  * @param event jQuery event.
  */
  ReportDataController.prototype.onItemClicked = function(item, event) {
    event.stopPropagation();
    event.preventDefault();
    if (this.initObject.isExplorer) {
      var prefix = '/' + ManageIQ.controller;
      $.post(prefix + '/x_show/' + item.id)
        .always(function() {
          this.setSandPaperClass();
        }.bind(this));
    } else {
      var prefix = this.initObject.showUrl;
      DoNav(prefix + '/' + item.id);
    }
    return false;
  }

  /**
  * Method which will be fired when item was selected (either trough select box or by clicking on tile).
  * @param item which item was selected.
  * @param isSelected true | false.
  */
  ReportDataController.prototype.onItemSelect = function(item, isSelected) {
    selectedItem = _.find(this.gtlData.rows, {id: item.id});
    selectedItem.checked = isSelected;
    selectedItem.selected = isSelected;
    sendDataWithRx({rowSelect: selectedItem});
    if (isSelected) {
      ManageIQ.gridChecks.push(item.id);
    } else {
      var index = ManageIQ.gridChecks.indexOf(item.id);
      index !== -1 && ManageIQ.gridChecks.splice(index, 1);
    }
  }

  ReportDataController.prototype.initObjects = function(initObject) {
    this.gtlData = { cols: [] ,rows: [] };
    this.initObject = initObject;
    this.gtlType = initObject.gtlType;
    this.settings.isLoading = true;
    ManageIQ.gridChecks = [];
    sendDataWithRx({setCount: 0});
  }

  /**
  * Method for initializing controller. Good for bootstraping controller after loading items. This method will call
  * getData for fetching data for current state. After these data were fetched, sorting items and filtering them takes
  * place.
  * @param initObject this object will hold all information about current state.
  * ```
  *   initObject: {
  *     modelName: string,
  *     gtlType: string,
  *     activeTree: string,
  *     currId: string,
  *     isExplorer: Boolean
  *   }
  * ```
  */
  ReportDataController.prototype.initController = function(initObject) {
    initObject.modelName = decodeURIComponent(initObject.modelName);
    this.initObjects(initObject);
    this.setSandPaperClass(initObject.gtlType);
    this.showMessage = this.$location.search().flash_msg;
    return this.getData(initObject.modelName, initObject.activeTree, initObject.currId, initObject.isExplorer, this.settings)
      .then(function(data) {
        var start = (this.settings.current - 1) * this.settings.perpage;
        this.setPaging(start, this.settings.perpage);
        var sortId = _.findIndex(this.gtlData.cols, {col_idx: parseInt(this.settings.sort_col, 10)});
        if (sortId !== -1) {
          this.setSort(sortId, this.settings.sort_dir === 'ASC');
        }
        this.settings.selectAllTitle = __('Select All');
        this.settings.sortedByTitle = __('Sorted By');
        this.settings.isLoading = false;
        return data;
      }.bind(this));
  }

  ReportDataController.prototype.setSandPaperClass = function(viewType) {
    var mainContent = document.getElementById('main-content');
    if (mainContent) {
      var mainConentClasses = mainContent.className.split(' ');
      var sandPaperIndex = mainConentClasses.indexOf('miq-sand-paper');
      if (sandPaperIndex != -1) {
        mainConentClasses.splice(sandPaperIndex, 1);
        mainContent.className = mainConentClasses.join(' ');
      }
      if (viewType && (viewType === 'grid' || viewType === 'tile')) {
        mainContent.className += ' miq-sand-paper';
      }
    }
  }

  /**
  * Method for fetching data from server. gtlData, settings and pePage is selected after fetching data.
  * @param modelName name of current model.
  * @param activeTree ID of active tree node.
  * @param currId current Id, if some nested items are displayed.
  * @param isExplorer true | false if we are in explorer part of application.
  * @param settings settings object.
  */
  ReportDataController.prototype.getData = function(modelName, activeTree, currId, isExplorer, settings) {
    return this.MiQDataTableService.retrieveRowsAndColumnsFromUrl(modelName, activeTree, currId, isExplorer, settings)
      .then(function (gtlData) {
        this.gtlData = gtlData;
        this.perPage.text = gtlData.settings.perpage;
        this.perPage.value = gtlData.settings.perpage;
        this.settings = gtlData.settings;
        return gtlData;
      }.bind(this));
  }

  ReportDataController.$inject = ['MiQDataTableService', 'MiQEndpointsService', '$filter', '$location', '$scope'];
  miqHttpInject(angular.module('ManageIQ.gtl'))
    .controller(COTNROLLER_NAME, ReportDataController);
})();
