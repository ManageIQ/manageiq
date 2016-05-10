(function(){
  /**
  * Define Default action which will be used as placeholder for empty data.
  */
  var setDefaultAction = function() {
    return {
      id: 'new_provider',
      title: __('Add a New Middleware Provider'),
      icon: 'pficon pficon-add-circle-o fa-lg',
      actionFunction: function(){
        this.defaultActionFunction();
      }.bind(this)
    };
  };

  /**
  * Define Toolbar Items, these items requre binding object which Contains
  * editSelected, removeSelected and editTags functions.
  */
  var setToolbarItems = function() {
    return [
      {
        title: __('Configuration'),
        icon: 'fa fa-cog fa-lg',
        children: [this.defaultAction, {
            id: 'edit_provider',
            title: __('Edit Selected Middleware Provider'),
            disabled: true,
            icon: 'pficon pficon-edit fa-lg',
            actionFunction: function(){
              this.editSelected();
            }.bind(this)
          }, {
            title: __('Remove Middleware Providers from the VMDB'),
            disabled: true,
            icon: 'pficon pficon-delete fa-lg',
            actionFunction: function(){
              this.removeSelected();
            }.bind(this)
        }]
      }, {
        title: __('Policy'),
        icon: 'fa fa-shield fa-lg',
        disabled: true,
        children: [{
          title: __('Edit Tags'),
          disabled: true,
          icon: 'pficon pficon-edit fa-lg',
          actionFunction: function(){
            this.editTags();
          }.bind(this)
        }]
      }
    ]
  }

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

  getDefaultView = function() {
    var lastIndex = window.location.pathname.lastIndexOf('/');
    if (lastIndex !== -1) {
      var defaultView = window.location.pathname.substring(lastIndex + 1);
      return (defaultView !== '')? defaultView : 'list';
    } else {
      return 'list';
    }
  }

  /**
  * ListProvidersController constructor.
  * @param  MiQDataTableService service with dataTable loading and sorting.
  * @param $state service for angular redirect.
  * @param $http provider for gets and posts.
  * @param MiQNotificationService service for accessing alerts messages.
  */
  var ListProvidersController = function(MiQDataTableService, $state, $http, MiQNotificationService) {
    this.MiQNotificationService = MiQNotificationService;
    this.$state = $state;
    this.$http = $http;
    this.activeView = getDefaultView();
    this.MiQDataTableService = MiQDataTableService;
    this.isSelectable = true;
    this.hasFooter = true;
    this.hasHeader = true;
    this.data = [];
    this.columnsToShow = [];
    this.defaultAction = setDefaultAction.bind(this)();
    this.toolbarItems = setToolbarItems.bind(this)();
    this.perPage = setPerPage.bind(this)();
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

  ListProvidersController.prototype.filterSelectedIds = function() {
    return _.chain(this.data)
                        .filter({selected: true})
                        .map('id')
                        .value();
  }

  /**
  * Method which removes selected item from VMDB.
  * TODO: Call delete function.
  */
  ListProvidersController.prototype.removeSelected = function() {
    var selectedIds = this.filterSelectedIds();
    if (selectedIds) {
      var shouldRemove = confirm(__('Are you sure you want to remove providers with IDs: ' + selectedIds.join(', ')));
      var lodaingItem = this.MiQNotificationService.sendInfo(
        this.MiQNotificationService.dismissibleMessage(
          __('Remove of providers with IDs ' + dataResponse.data.removedIds.join(', ') +' initiated')
        )
      );
      if (shouldRemove) {
        this.deleteItems(selectedIds, lodaingItem);
      }
    }
  };

  ListProvidersController.prototype.deleteItems = function(items, loadingItem) {
    this.$http({
      url: '/ems_middleware/delete_provider',
      method: 'POST',
      data: {miq_grid_checks: selectedIds.join(',')},
    }).then(function(dataResponse){
      this.MiQNotificationService.sendSuccess(
        this.MiQNotificationService.dismissibleMessage(
          __('Remove of providers with IDs ' + dataResponse.data.removedIds.join(', ') +' was successful', null, lodaingItem)
        )
      );
      this.loadData();
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
    _.each(this.toolbarItems, function(oneToolbarItem) {
      if (oneToolbarItem.title !== 'Configuration') {
        oneToolbarItem.disabled = disabled;
      }
      _.each(oneToolbarItem.children, function(oneChild) {
        if (oneChild.id !== 'new_provider') {
          oneChild.disabled = disabled;
        }
        if (countSelected > 1 && oneChild.id === 'edit_provider') {
          oneChild.disabled = true;
        }
      })
    });
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
    return this.MiQDataTableService.retrieveRowsAndColumnsFromUrl().then(function(rowsCols){
      this.assignData(rowsCols);
      return rowsCols;
    }.bind(this));
  };

  /**
  * Method for assigning data which are recieved from server.
  * @param rowsCols object with rows and columns from server.
  */
  ListProvidersController.prototype.assignData = function(rowsCols) {
    this.data = rowsCols.rows;
    this.columnsToShow = rowsCols.cols;
  };

  ListProvidersController.$inject = ['MiQDataTableService', '$state', '$http', 'MiQNotificationService'];
  miqHttpInject(angular.module('middleware.provider'))
  .controller('miqListProvidersController', ListProvidersController);
})();
