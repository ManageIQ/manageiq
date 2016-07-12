(function(){

  var ToolbarController = function(MiQToolbarSettingsService, MiQEndpointsService, $scope) {
    this.MiQToolbarSettingsService = MiQToolbarSettingsService;
    this.MiQEndpointsService = MiQEndpointsService;
    this.$scope = $scope;
    this.isList = _.contains(location.pathname, 'show_list');
    this.initEndpoints();
    this.subscribeToSubject();
  }

  ToolbarController.prototype.subscribeToSubject = function() {
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

  ToolbarController.prototype.onRowSelect = function(data) {
    this.MiQToolbarSettingsService.checkboxClicked(data.checked);
    this.$scope.$digest();
  }

  ToolbarController.prototype.init = function() {
    this.MiQToolbarSettingsService.getSettings(this.isList).then(function(toolbarItems) {
      this.toolbarItems = toolbarItems;
    }.bind(this));
  }

  ToolbarController.prototype.initEndpoints = function() {
    var urlPrefix = '/' + location.pathname.split('/')[1];
    if (urlPrefix) {
      this.MiQEndpointsService.rootPoint = urlPrefix;
    }
  }

  ToolbarController.$inject = ['MiQToolbarSettingsService', 'MiQEndpointsService', '$scope'];
  miqHttpInject(angular.module('ManageIQ.toolbar'))
    .controller('miqToolbarController', ToolbarController);
})();
