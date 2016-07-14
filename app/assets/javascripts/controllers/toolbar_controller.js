(function(){

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

  function initEndpoints(MiQEndpointsService) {
    var urlPrefix = '/' + location.pathname.split('/')[1];
    if (urlPrefix) {
      MiQEndpointsService.rootPoint = urlPrefix;
    }
  }

  var ToolbarController = function(MiQToolbarSettingsService, MiQEndpointsService, $scope) {
    this.MiQToolbarSettingsService = MiQToolbarSettingsService;
    this.MiQEndpointsService = MiQEndpointsService;
    this.$scope = $scope;
    initEndpoints(this.MiQEndpointsService);
    this.isList = _.contains(location.pathname, 'show_list');
    subscribeToSubject.bind(this)();
  }

  ToolbarController.prototype.onRowSelect = function(data) {
    this.MiQToolbarSettingsService.checkboxClicked(data.checked);
    if(!this.$scope.$$phase) {
      this.$scope.$digest();
    }
  }

  ToolbarController.prototype.init = function() {
    return this.MiQToolbarSettingsService.getSettings(this.isList).then(function(toolbarItems) {
      this.toolbarItems = toolbarItems;
      return toolbarItems;
    }.bind(this));
  }

  ToolbarController.$inject = ['MiQToolbarSettingsService', 'MiQEndpointsService', '$scope'];
  miqHttpInject(angular.module('ManageIQ.toolbar'))
    .controller('miqToolbarController', ToolbarController);
})();
