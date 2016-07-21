(function(){

  /**
  * Private method for subscribing to rxSubject.
  * For success functuon @see ToolbarController#onRowSelect()
  */
  function subscribeToSubject() {
    ManageIQ.angular.rxSubject.subscribe(function(event) {
      if (event.rowSelect) {
        this.onRowSelect(event.rowSelect);
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

  function generateGetData(type, lastaction, display) {
    var getData = {
      id: ManageIQ.record.recordId,
      gtl_type: type,
      lastAction: lastaction,
      display: display
    }
    return _.pick(getData, _.identity);
  }

  /**
  * Constructor of angular's miqToolbarController.
  * @param MiQToolbarSettingsService toolbarSettings service from ui-components.
  * @param MiQEndpointsService endpoits service from ui-components.
  * @param $scope service for managing $scope (for apply and digest reasons).
  * @param $location service for managing browser's location.
  * this contructor will assign all params to `this`, it will init endpoits, set if toolbar is used on list page.
  */
  var ToolbarController = function(MiQToolbarSettingsService, MiQEndpointsService, $scope,$location) {
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
      .filter({type: 'button'})
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
  ToolbarController.prototype.onViewClick = function(item) {
    var tail = (ManageIQ.record.recordId) ? ManageIQ.record.recordId : '';
    location.replace('/' + ManageIQ.controller + item.url + tail + item.url_parms);
  }

  /**
  * Default init method for non angularized views.
  * It will bind this controller to rxSubject, fetches data, filter Data views and sets default view's url. All these
  * methods are public, except subscribeToSubject.
  */
  ToolbarController.prototype.init = function(type, lastaction, display) {
    subscribeToSubject.bind(this)();
    return this.fetchData(generateGetData(type, lastaction, display)).then(function() {
      this.defaultViewUrl();
      this.setClickHandler();
    }.bind(this));
  }

  ToolbarController.prototype.initObject = function(toolbarString) {
    toolbarItems = this.MiQToolbarSettingsService.generateToolbarObject(JSON.parse(toolbarString));
    this.toolbarItems = toolbarItems.items;
    this.dataViews = toolbarItems.dataViews;
    this.defaultViewUrl();
    this.setClickHandler();
  }

  ToolbarController.$inject = ['MiQToolbarSettingsService', 'MiQEndpointsService', '$scope', '$location'];
  miqHttpInject(angular.module('ManageIQ.toolbar'))
    .controller('miqToolbarController', ToolbarController);
})();
