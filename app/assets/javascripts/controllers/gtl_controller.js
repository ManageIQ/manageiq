(function(){
  COTNROLLER_NAME = 'miqGtlContoller';

  /**
  * Private method for setting rootPoint of MiQEndpointsService.
  * @param MiQEndpointsService service responsible for endpoits.
  */
  function initEndpoints(MiQEndpointsService) {
    MiQEndpointsService.rootPoint = '/' + ManageIQ.controller;
    MiQEndpointsService.endpoints.listDataTable = '/' + ManageIQ.constants.gtlList;
  }

  function defaultPaging() {
    return {
      label: __('Items per page'),
      enabled: true,
      text: 10,
      value: 10,
      hidden: false,
      items: [
        {text: 5, value: 5, hidden: false, enabled: true},
        {text: 10, value: 10, hidden: false, enabled: true},
        {text: 20, value: 20, hidden: false, enabled: true},
        {text: 50, value: 50, hidden: false, enabled: true},
        {text: 100, value: 100, hidden: false, enabled: true},
        {text: 1000, value: 1000, hidden: false, enabled: true},
        {text: __('All'), value: -1, hidden: false, enabled: true},
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

  var GtlController = function(MiQDataTableService, MiQEndpointsService, $scope, $location, $filter) {
    this.MiQDataTableService = MiQDataTableService;
    this.MiQEndpointsService = MiQEndpointsService;
    this.$scope = $scope;
    this.$filter = $filter;
    initEndpoints(this.MiQEndpointsService);
    subscribeToSubject.bind(this)();
    this.$location = $location;
    this.perPage = defaultPaging();
  }

  GtlController.prototype.onSort = function(headerId, isAscending) {
    this.settings.sortBy = {
      sortObject: this.gtlData.cols[headerId],
      isAscending: isAscending
    };
    this.filterAndSort();
  }

  GtlController.prototype.onLoadNext = function(start, perPage) {
    this.perPage.value = perPage;
    this.perPage.text = perPage;
    this.settings.perpage = perPage;
    this.settings.startIndex = start;
    this.settings.current = ( start / perPage) + 1;
    this.settings.total = Math.ceil(this.settings.items / this.settings.perpage);
    this.filterAndSort();
  }

  GtlController.prototype.onItemClicked = function(item) {
    console.log(this.settings.base_url + '/show/' + item.id);
    console.log(item, 'sdfsdfsdfsfd');
  }

  GtlController.prototype.filterAndSort = function() {
    this.filteredRows = this.gtlData.rows;
    if (this.settings.sortBy) {
      this.sortItems();
    }
    this.limitTo();
  }

  GtlController.prototype.limitTo = function() {
    this.filteredRows = this.$filter('limitTo')(this.filteredRows, this.settings.perpage, this.settings.startIndex);
    return this.filteredRows;
  }

  GtlController.prototype.sortItems = function() {
    this.filteredRows = _.sortBy(this.filteredRows, function(row) {
      var indexOfColumn = this.gtlData.cols.indexOf(this.settings.sortBy.sortObject);
      return row.cells[indexOfColumn].text;
    }.bind(this));
    this.filteredRows = this.settings.sortBy.isAscending ? this.filteredRows : this.filteredRows.reverse();
    return this.filteredRows;
  }

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

  GtlController.prototype.initController = function(initObject) {
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
      }.bind(this))
  }

  GtlController.prototype.getData = function(modelName, activeTree, currId) {
    return this.MiQDataTableService.retrieveRowsAndColumnsFromUrl(modelName, activeTree, currId)
      .then(function (gtlData) {
        this.gtlData = gtlData;
        this.perPage.text = gtlData.settings.perpage;
        this.settings = gtlData.settings;
      }.bind(this));
  }

  GtlController.$inject = ['MiQDataTableService', 'MiQEndpointsService', '$scope', '$location', '$filter'];
  miqHttpInject(angular.module('ManageIQ.gtl'))
    .controller(COTNROLLER_NAME, GtlController);
})();
