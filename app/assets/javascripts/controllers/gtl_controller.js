(function(){
  var COTNROLLER_NAME = 'miqGtlContoller';

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
    ManageIQ.angular.rxSubject.subscribe(function(event) {
      if (event.initController && event.initController.name === COTNROLLER_NAME) {
        this.initController(event.initController.data)
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
  var GtlController = function(MiQDataTableService, MiQEndpointsService, $filter) {
    this.MiQDataTableService = MiQDataTableService;
    this.MiQEndpointsService = MiQEndpointsService;
    this.$filter = $filter;
    initEndpoints(this.MiQEndpointsService);
    subscribeToSubject.bind(this)();
    this.perPage = defaultPaging();
  }

  /**
  * Method for handeling sort function. This will be called when sort of items will be needed. This method will set
  * sort object to settings and calls method for filtering and sorting.
  * @param headerId ID of column which is sorted by.
  * @param isAscending true | false.
  */
  GtlController.prototype.onSort = function(headerId, isAscending) {
    this.settings.sortBy = {
      sortObject: this.gtlData.cols[headerId],
      isAscending: isAscending
    };
    this.filterAndSort();
  }

  /**
  * Method for loading more items, either by selecting next page, or by choosing different number of items per page.
  * It will calculate start index of page and will call method for filtering and sorting items.
  * @param start index of item, which will be taken as start item.
  * @param perPage Number of items per page.
  */
  GtlController.prototype.onLoadNext = function(start, perPage) {
    this.perPage.value = perPage;
    this.perPage.text = perPage;
    this.settings.perpage = perPage;
    this.settings.startIndex = start;
    this.settings.current = ( start / perPage) + 1;
    this.settings.total = Math.ceil(this.settings.items / this.settings.perpage);
    this.filterAndSort();
  }

  /**
  * Method for handeling clicking on item (either gliphicon or item). It will perform navigation or post message based
  * on type of items.
  * @param item which item was clicked.
  * @param event jQuery event.
  */
  GtlController.prototype.onItemClicked = function(item, event) {
    event.stopPropagation();
    event.preventDefault();
    if (this.initObject.isExplorer) {
      var prefix = '/' + ManageIQ.controller;
      $.post(prefix + '/x_show/' + item.id);
    } else {
      var url = this.initObject.showUrl + '/' + item.id;
      DoNav(url);
    }
    return false;
  }

  /**
  * Method for filtering and sorting items. This method will call sort items if it sort item was specified and will call
  * limitTo method for filtering number of items.
  */
  GtlController.prototype.filterAndSort = function() {
    this.filteredRows = this.gtlData.rows;
    if (this.settings.sortBy) {
      this.sortItems();
    }
    this.limitTo();
  }

  /**
  * Method for filtering number of active items. Filter called `limitTo` is used.
  * @return array of filtered items.
  */
  GtlController.prototype.limitTo = function() {
    this.filteredRows = this.$filter('limitTo')(this.filteredRows, this.settings.perpage, this.settings.startIndex);
    return this.filteredRows;
  }

  /**
  * Method for sorting items. This method uses lodash's sortBy function.
  * @return array of sorted items.
  */
  GtlController.prototype.sortItems = function() {
    this.filteredRows = _.sortBy(this.filteredRows, [function(row) {
      var indexOfColumn = this.gtlData.cols.indexOf(this.settings.sortBy.sortObject);
      return row.cells[indexOfColumn].text;
    }.bind(this)]);
    this.filteredRows = this.settings.sortBy.isAscending ? this.filteredRows : this.filteredRows.reverse();
    return this.filteredRows;
  }

  /**
  * Method which will be fired when item was selected (either trough select box or by clicking on tile).
  * @param item which item was selected.
  * @param isSelected true | false.
  */
  GtlController.prototype.onItemSelect = function(item, isSelected) {
    selectedItem = _.find(this.gtlData.rows, {id: item.id});
    selectedItem.checked = isSelected;
    sendDataWithRx({rowSelect: selectedItem});
    if (isSelected) {
      ManageIQ.gridChecks.push(item.id);
    } else {
      var index = ManageIQ.gridChecks.indexOf(item.id);
      index !== -1 && ManageIQ.gridChecks.splice(index, 1);
    }
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
  GtlController.prototype.initController = function(initObject) {
    this.gtlData = { cols: [] ,rows: [] };
    this.initObject = initObject;
    this.gtlType = initObject.gtlType;
    return this.getData(initObject.modelName, initObject.activeTree, initObject.currId)
      .then(function() {
        var start = (this.settings.current - 1) * this.settings.perpage;
        this.onLoadNext(start, this.settings.perpage);
        var sortId = _.findIndex(this.gtlData.cols, {col_idx: parseInt(initObject.sortColIdx, 10)});
        if (sortId !== -1) {
          this.onSort(sortId, initObject.sortDir === 'ASC');
        } else {
          this.filterAndSort();
        }
        this.settings.selectAllTitle = __('Select All');
        this.settings.sortedByTitle = __('Sorted By');
      }.bind(this))
  }

  /**
  * Method for fetching data from server. gtlData, settings and pePage is selected after fetching data.
  * @param modelName name of current model.
  * @param activeTree ID of active tree node.
  * @param currId current Id, if some nested items are displayed.
  */
  GtlController.prototype.getData = function(modelName, activeTree, currId) {
    return this.MiQDataTableService.retrieveRowsAndColumnsFromUrl(modelName, activeTree, currId)
      .then(function (gtlData) {
        this.gtlData = gtlData;
        this.perPage.text = gtlData.settings.perpage;
        this.settings = gtlData.settings;
      }.bind(this));
  }

  GtlController.$inject = ['MiQDataTableService', 'MiQEndpointsService', '$filter'];
  miqHttpInject(angular.module('ManageIQ.gtl'))
    .controller(COTNROLLER_NAME, GtlController);
})();
