(function(){

  /**
  * Define Per Page items.
  */
  var setPerPage = function() {
    return {
      title: '5',
      children: [
          {title: '5', value: 5},
          {title: '10', value: 10},
          {title: '20', value: 20},
          {title: '100', value: 100},
          {title: __('All'), value: -1}
      ]
    }
  }

  /**
  * Function for binding toolbarIds with functions.
  * Which object should be used is determined by las index of '_' in ID and text after '_'
  * If isDefault is set this method will be used as default in datables.
  */
  setFunctionReference = function() {
    return {
      '_tag': {
        actionFunction: function(){
          this.editTags();
        }.bind(this)
      },
      '_delete': {
        actionFunction: function(){
          this.removeSelected();
        }.bind(this)
      },
      '_new': {
        isDefault: true,
        actionFunction: function(){
          this.defaultActionFunction();
        }.bind(this)
      }
    };
  }

  /**
  * Function which iterates trough each item of toolbar and bind functions to it.
  * @see #setFunctionReference() for reference how to add new function bind.
  */
  setFunctionsForToolbar = function() {
    _.chain(this.toolbarItems)
      .flatten()
      .map('items')
      .flatten()
      .each(function(item) {
        if (item && item.hasOwnProperty('id')) {
          var lastIndex = item.id.lastIndexOf('_');
          var identifier = item.id.substring(lastIndex);
          if (this.functionReference.hasOwnProperty(identifier)) {
            item.actionFunction = this.functionReference[identifier].actionFunction;
            this.functionReference[identifier].isDefault && (this.defaultAction = item);
          }
        }
      }.bind(this))
      .value();
  }

  /**
  * This function will handle fetching of defaultView based on location.
  */
  getDefaultView = function() {
    var defaultState = unescape(window.location.hash);
    var lastIndex = defaultState.lastIndexOf('/');
    if (lastIndex !== -1) {
      var defaultView = defaultState.substring(lastIndex + 1);
      return (defaultView !== '')? defaultView : 'list';
    } else {
      return 'list';
    }
  }

  /**
  * Function fo enabling or disabling items in toolbar.
  * It is based on onwhen property of toolbarItem.
  * @param toolbarItem this item will enabled/disabled.
  * @param countSelected number of selected items.
  */
  enableToolbarItemByCountSelected = function(toolbarItem, countSelected) {
    if (toolbarItem.onwhen) {
      if (toolbarItem.onwhen.slice(-1) === '+') {
        toolbarItem.enabled = countSelected >=  toolbarItem.onwhen.slice(0, toolbarItem.onwhen.length - 1);
      } else {
        toolbarItem.enabled = countSelected === parseInt(toolbarItem.onwhen);
      }
    }
  }

  observeOnChanges = function() {
    Rx.Observable.pairs(ManageIQ.angular.dataAccessor).subscribe(function(event){
      console.log(event);
    }.bind(this));
  }

  enableTreeOnStateChange = function() {
    this.$scope.$on('$stateChangeSuccess', function() {
      this.hasTree = this.$state.current.hasTree;
    }.bind(this));
    Rx.Observable.pairs(this.$state).subscribe(function(){
      this.hasTree = this.$state.current.hasTree;
    }.bind(this));
  }

  /**
  * ListProvidersController constructor.
  * @param  MiQDataTableService service with dataTable loading and sorting.
  * @param $state service for angular redirect.
  * @param $http provider for gets and posts.
  * @param MiQNotificationService service for accessing alerts messages.
  */
  var ListProvidersController = function(
    MiQDataTableService,
    $state, $http, MiQNotificationService,
    MiQToolbarSettingsService,
    MiQProvidersSettingsService,
    $scope,
    MiQEndpointsService
  ) {
    this.$scope = $scope;
    this.MiQToolbarSettingsService = MiQToolbarSettingsService;
    this.MiQNotificationService = MiQNotificationService;
    this.MiQDataTableService = MiQDataTableService;
    this.$state = $state;
    this.$http = $http;
    this.MiQProvidersSettingsService = MiQProvidersSettingsService;
    this.MiQEndpointsService = MiQEndpointsService;

    this.initEndpoints();

    this.isList = true;
    this.data = [];
    this.columnsToShow = [];
    this.perPage = setPerPage.bind(this)();
    this.activeView = getDefaultView();

    observeOnChanges.bind(this)();
    enableTreeOnStateChange.bind(this)();
  };

  /**
  * Edit Tags method, it will redirect user to specific URL.
  */
  ListProvidersController.prototype.editTags = function() {
    var selectedIds = this.filterSelectedIds();
    this.$http.post('/ems_middleware/edit_tags', {miq_grid_checks: selectedIds})
    .then(function(responseData) {
      window.location = '/ems_middleware/tagging_edit?db=' + responseData.data.db;
    });
  }

  /**
  * Default action function which is used when default action is triggered.
  */
  ListProvidersController.prototype.defaultActionFunction = function() {
    this.$state.go('new_provider');
  };

  /**
  * Method for edditing selected item.
  * This method currently calls redirect for edit,
  * TODO: angularize edit provider.
  */
  ListProvidersController.prototype.editSelected = function() {
    var selectedItem = _.find(this.data, {selected: true});
    if (selectedItem) {
      window.location = '/ems_middleware/edit/' + selectedItem.id;
    }
  };

  /**
  */
  ListProvidersController.prototype.filterSelectedIds = function() {
    return _
      .chain(this.data)
      .filter({selected: true})
      .map('id')
      .value();
  }

  /**
  * Method which removes selected item from VMDB.
  */
  ListProvidersController.prototype.removeSelected = function() {
    var selectedIds = this.filterSelectedIds();
    if (selectedIds) {
      var shouldRemove = confirm(__('Are you sure you want to remove providers with IDs: ' + selectedIds.join(', ')));
      var loadingItem = this.MiQNotificationService.sendLoading(
        this.MiQNotificationService.dismissibleMessage(
          __('Remove of providers with IDs ' + selectedIds.join(', ') +' initiated')
        )
      );
      if (shouldRemove) {
        this.deleteItems(selectedIds, loadingItem);
      }
    }
  };

  /**
  */
  ListProvidersController.prototype.deleteItems = function(items, loadingItem) {
    this.MiQDataTableService.deleteItems({miq_grid_checks: items.join(',')})
      .then(function(responseData){
        this.MiQNotificationService.sendSuccess(
          this.MiQNotificationService.dismissibleMessage(
            __('Remove of providers with IDs ') + responseData.removedIds.join(', ') + __(' was successful'), '', loadingItem
          )
        );
        this.data = this.MiQDataTableService.rows;
      }.bind(this));
  }

  /**
  * Method for showing detail of middleware provider.
  * TODO: angularize provider detail.
  * @param $event jquery event data object.
  * @param rowData which row was clicked.
  */
  ListProvidersController.prototype.onRowClick = function($event, rowData) {
    miqRowClick(rowData.id, '/ems_middleware/show/', false);
    return false;
  };

  /**
  * Method for handeling event after selection of any item.
  * Specific items in toolbarMenu will be enabled.
  */
  ListProvidersController.prototype.onRowSelected = function() {
    var disabled = _.findIndex(this.data, {selected: true}) === -1;
    var countSelected = _.countBy(this.data, {selected: true})['true'];
    _.chain(this.toolbarItems)
      .flatten()
      .each(function(item){
        if (item) {
          enableToolbarItemByCountSelected(item, countSelected);
          _.each(item.items, function(oneButton){
            enableToolbarItemByCountSelected(oneButton, countSelected);
          });
        }
      })
      .value();
  };

  /**
  * Method for getting what class should be used in each data view.
  * @param activateLink what kind of data view is used.
  */
  ListProvidersController.prototype.getClassByLocation = function(activateLink) {
    return {
      active: this.activeView === activateLink
    }
  };

  /**
  * Method which is called after selecting number of items per page.
  * @param item how many records should be displayed.
  */
  ListProvidersController.prototype.onPerPage = function(item) {
    this.perPage.title = item.title;
    this.MiQDataTableService.setPerPage(item.value);
  };

  /**
  * Method for loading data from MiQDataTableService.
  * @see MiQDataTableService#retrieveRowsAndColumnsFromUrl for referencing how data are loaded.
  * It uses promises and calls #assignData(rowsCols) for handeling recieved data.
  */
  ListProvidersController.prototype.loadData = function() {
    this.MiQProvidersSettingsService.getSettings().then(function(providersSettings) {
      this.isSelectable = providersSettings.isSelectable;
      this.noFooter = providersSettings.noFooter;
      this.hasHeader = providersSettings.hasHeader;
      this.title = providersSettings.title;
    }.bind(this));

    this.MiQToolbarSettingsService.getSettings(this.isList).then(function(toolbarItems) {
      this.functionReference = setFunctionReference.bind(this)();
      this.toolbarItems = toolbarItems;
      setFunctionsForToolbar.bind(this)();
    }.bind(this));

    return this.MiQDataTableService.retrieveRowsAndColumnsFromUrl().then(function(rowsCols) {
      this.$state.go('list_providers.' + this.activeView);
      this.assignData(rowsCols);
      return rowsCols;
    }.bind(this));
  };

  ListProvidersController.prototype.initEndpoints = function() {
    var urlPrefix = '/' + location.pathname.split('/')[1];
    if (urlPrefix) {
      this.MiQEndpointsService.rootPoint = urlPrefix;
    }
    this.MiQEndpointsService.endpoints.listDataTable = '/list_providers';
    this.MiQEndpointsService.endpoints.deleteItemDataTable = '/delete_provider';
  }

  /**
  * Method for assigning data which are recieved from server.
  * @param rowsCols object with rows and columns from server.
  */
  ListProvidersController.prototype.assignData = function(rowsCols) {
    this.data = rowsCols.rows;
    this.columnsToShow = rowsCols.cols;
  };

  ListProvidersController.$inject = ['MiQDataTableService', '$state', '$http',
  'MiQNotificationService', 'MiQToolbarSettingsService',
  'MiQProvidersSettingsService', '$scope', 'MiQEndpointsService'];
  miqHttpInject(angular.module('miq.provider'))
  .controller('miqListProvidersController', ListProvidersController);
})();
