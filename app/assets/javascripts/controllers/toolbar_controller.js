(function(){

  function isButton(item) {
    return item.type === 'button';
  }

  function isButtonTwoState(item) {
    return item.type === 'buttonTwoState' && item.id.indexOf('view') === -1;
  }

  /**
  * Private method for subscribing to rxSubject.
  * For success functuon @see ToolbarController#onRowSelect()
  */
  function subscribeToSubject() {
    listenToRx(function(event) {
      if (event.rowSelect) {
        this.onRowSelect(event.rowSelect);
      } else if (event.redrawToolbar) {
         this.onUpdateToolbar(event.redrawToolbar);
      } else if (event.update) {
        this.onUpdateItem(event);
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
  * Private method for setting rootPoint of MiQEndpointsService.
  * @param MiQEndpointsService service responsible for endpoits.
  */
  function initEndpoints(MiQEndpointsService) {
    var urlPrefix = '/' + location.pathname.split('/')[1];
    if (urlPrefix) {
      MiQEndpointsService.rootPoint = urlPrefix;
    }
  }

  /**
  * Constructor of angular's miqToolbarController.
  * @param MiQToolbarSettingsService toolbarSettings service from ui-components.
  * @param MiQEndpointsService endpoits service from ui-components.
  * @param $scope service for managing $scope (for apply and digest reasons).
  * @param $location service for managing browser's location.
  * this contructor will assign all params to `this`, it will init endpoits, set if toolbar is used on list page.
  */
  var ToolbarController = function(MiQToolbarSettingsService, MiQEndpointsService, $scope, $location) {
    this.MiQToolbarSettingsService = MiQToolbarSettingsService;
    this.MiQEndpointsService = MiQEndpointsService;
    this.$scope = $scope;
    this.$location = $location;
    initEndpoints(this.MiQEndpointsService);
    this.isList = _.contains(location.pathname, 'show_list');
  }

  /**
  * Public method which is executed after row in gtl is selected.
  */
  ToolbarController.prototype.onRowSelect = function(data) {
    this.MiQToolbarSettingsService.checkboxClicked(data.checked);
    if(!this.$scope.$$phase) {
      this.$scope.$digest();
    }
  }

  /**
  * Public method for setting up url of data views, based on last path param (e.g. /show_list).
  */
  ToolbarController.prototype.defaultViewUrl = function() {
    this.dataViews.forEach(function(item) {
      if (item.url === "") {
        var lastSlash = location.pathname.lastIndexOf('/');
        item.url = (lastSlash !== -1) ? location.pathname.substring(lastSlash): "";
      }
    });
  }

  /**
  * Method which will retrieves toolbar settings from server.
  * @see MiQToolbarSettingsService#getSettings for more info.
  * Settings is called with this.isList and $location search object with value of `type`.
  * No need to worry about multiple search params and no complicated function for parsing is needed.
  */
  ToolbarController.prototype.fetchData = function(getData) {
    return this.MiQToolbarSettingsService
      .getSettings(getData)
      .then(function(toolbarItems) {
        this.toolbarItems = toolbarItems.items;
        this.dataViews = toolbarItems.dataViews;
      }.bind(this));
  }

  /**
  *
  */
  ToolbarController.prototype.setClickHandler = function() {
    var buttons = _
      .chain(this.toolbarItems)
      .flatten()
      .map(function(item) {
        return (item && item.hasOwnProperty('items')) ? item.items : item;
      })
      .flatten()
      .filter(function(item){
        return item.type &&
          (isButton(item) || isButtonTwoState(item))
      })
      .each(function(item) {
        item.eventFunction = function($event) {
          miqToolbarOnClick.bind($event.delegateTarget)($event);
        }
      })
      .value();
  }

 /**
 * Public method for changing view over data.
 */
  ToolbarController.prototype.onViewClick = function(item, $event) {
    if (item.url.indexOf('/') === 0) {
      var delimiter = (item.url === '/') ? '' : '/';
      var tail = (ManageIQ.record.recordId) ? delimiter + ManageIQ.record.recordId : '';

      location.replace('/' + ManageIQ.controller + item.url + tail + item.url_parms);
    } else {
      miqToolbarOnClick.bind($event.delegateTarget)($event);
    }
  }

  ToolbarController.prototype.initObject = function(toolbarString) {
    subscribeToSubject.bind(this)();
    this.updateToolbar(JSON.parse(toolbarString));
  }

  ToolbarController.prototype.onUpdateToolbar = function(toolbarObject) {
    this.updateToolbar(toolbarObject);
    if(!this.$scope.$$phase) {
      this.$scope.$digest();
    }
  }

  ToolbarController.prototype.onUpdateItem = function(updateData) {
    var toolbarItem = _.find(_.flatten(this.toolbarItems), {id: updateData.update});
    if (toolbarItem && toolbarItem.hasOwnProperty(updateData.type)) {
      toolbarItem[updateData.type] = updateData.value;
      if(!this.$scope.$$phase) {
        this.$scope.$digest();
      }
    }
  }

  ToolbarController.prototype.updateToolbar = function(toolbarObject) {
    toolbarItems = this.MiQToolbarSettingsService.generateToolbarObject(toolbarObject);
    this.toolbarItems = toolbarItems.items;
    this.dataViews = toolbarItems.dataViews;
    this.defaultViewUrl();
    this.setClickHandler();
  }

  ToolbarController.$inject = ['MiQToolbarSettingsService', 'MiQEndpointsService', '$scope', '$location'];
  miqHttpInject(angular.module('ManageIQ.toolbar'))
    .controller('miqToolbarController', ToolbarController);
})();
