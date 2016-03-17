miqHttpInject(angular.module('mwProviders.controllers', ['miQStaticAssets', 'rx']))
.config(function(MiQDataAccessServiceProvider, MiQFormValidatorServiceProvider, MiQDataTableServiceProvider) {
  MiQDataAccessServiceProvider.setUrlPrefix('/ems_middleware');
  MiQDataTableServiceProvider.endpoints = {
    list: '/list_providers'
  };
  MiQFormValidatorServiceProvider.endpoints = {
    validate: '/validate_provider',
    create: '/new_provider'
  }
})
.controller('miqNewProviderController', ['$location', '$http', 'MiQFormValidatorService', 'MiQNotificationService', function($location, $http, MiQFormValidatorService, MiQNotificationService) {

  this.onBackToListClick = _.bind(function() {
    $location.path('/ems_middleware/show_list/list');
    MiQNotificationService.sendSuccess(
      MiQNotificationService.dismissibleMessage(__('Validation Successfull'))
    );
  }, this);

  this.stripProtocol = _.bind(function(item) {
    item.hostname = item.hostname.replace(/.*?:\/\//g, "");
    if (item.hostname.lastIndexOf('/') === item.hostname.length - 1) {
      item.hostname = item.hostname.slice(0,-1);
    }
  }, this);

  this.validateAction = _.bind(function(validateData) {
    var loadingItem = MiQNotificationService.sendLoading(
      MiQNotificationService.dismissibleMessage(__('Validation in progress'))
    );
    this.stripProtocol(this.newProvider);
    MiQFormValidatorService.validateObject(this.newProvider).then(function (formResponseData) {
      if (!formResponseData.isValid) {
        MiQNotificationService.sendDanger(
          MiQNotificationService.dismissibleMessage(formResponseData.errorMsg, __('Validation Error: '), loadingItem)
        );
      } else {
        MiQNotificationService.sendSuccess(
          MiQNotificationService.dismissibleMessage(__('Validation Successfull'), '', loadingItem)
        );
      }
    });
  }, this);

  this.formActions = [{
    btnClass: 'btn-primary',
    title: __('Add this Middleware Manager'),
    validate: true,
    clickFunction: _.bind(function() {
      MiQFormValidatorService.saveObject(this.newProvider).then(_.bind(function (formResponseData) {
        var loadingItem = MiQNotificationService.sendLoading(
          MiQNotificationService.dismissibleMessage(__('Save in progress'))
        );
        this.stripProtocol(this.newProvider);
        if(formResponseData.isValid) {
          this.onBackToListClick();
        } else {
          if (formResponseData.errorMsg) {
            MiQNotificationService.sendDanger(MiQNotificationService.dismissibleMessage(formResponseData.errorMsg, __('Save Error'), loadingItem));
          }
          _.each(formResponseData.serverAlerts, _.bind(function(item, key){
            MiQNotificationService.sendDanger(MiQNotificationService.dismissibleMessage(item, key, loadingItem));
          }, this))
        }
      }, this));
    }, this),
    label: __('Add')
  }, {
    btnClass: 'btn-default',
    title: __('Cancel and return to list of Middleware providers'),
    clickFunction: _.bind(function() {
      this.onBackToListClick();
    }, this),
    label: __('Cancel')
  }];

  this.credentialsTabs = [{
    title: __('Default'),
    description: __('Required. Should have privileged access, such as root or administrator.'),
    modelKey: 'default'
  }, {
    title: __('Remote login'),
    description: __('Required if SSH login is disabled for the Default account.'),
    modelKey: 'remoteLogin'
  }, {
    title: __('Web services'),
    description: __('Used for access to Web Services.'),
    modelKey: 'webServices'
  }, {
    title: __('IPMI'),
    description: __('Used for access to IPMI.'),
    modelKey: 'impi'
  }];

  this.types = [__('Hawkular')];

  this.zones = [__('Dan'), __('Dan 2 Zone'), __('Default Zone'), __('RHEV 1 for fleecing')];

  this.newProvider = {
    type: 'default',
    zone: __('Default Zone'),
    remoteLogin: {},
    webServices: {},
    impi: {}
  };
}])
.controller('miqListProvidersController', ['MiQDataTableService', '$location', function(MiQDataTableService, $location) {
    this.activeView = 'list';
    this.isSelectable = true;
    this.hasFooter = true;
    this.data = [];
    this.columnsToShow = [];
    this.defaultAction = {
      id: 'new_provider',
      title: __('Add a New Middleware Provider'),
      icon: 'pficon pficon-add-circle-o fa-lg',
      actionFunction: _.bind(function() {
        $location.path('/ems_middleware/new');
      }, this)
    };
    MiQDataTableService.retrieveRowsAndColumnsFromUrl(
      '/list_providers'
    ).then(_.bind(function(rowsCols){
      this.data = rowsCols.rows;
      this.columnsToShow = rowsCols.cols;
    }, this));

    this.onRowClick = function($event, rowData) {
      miqRowClick(rowData.id, '/ems_middleware/show/', false);
      return false;
    };

    this.onRowSelected = _.bind(function() {
      const disabled = _.findIndex(this.data, {selected: true}) === -1;
      const countSelected = _.countBy(this.data, {selected: true})['true'];
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
      })
    }, this);

    this.getClassByLocation = _.bind(function(activateLink) {
      return {
        active: this.activeView === activateLink
      }
    }, this);

    this.toolbarItems = [
      {
        title: __('Configuration'),
        icon: 'fa fa-cog fa-lg',
        children: [this.defaultAction, {
            id: 'edit_provider',
            title: __('Edit Selected Middleware Provider'),
            disabled: true,
            icon: 'pficon pficon-edit fa-lg',
            actionFunction: _.bind(function() {
              const selectedItem = _.find(this.data, {selected: true});
              if (selectedItem) {
                window.location = '/ems_middleware/edit/' + selectedItem.id;
              }
            }, this)
          }, {
            title: __('Remove Middleware Providers from the VMDB'),
            disabled: true,
            icon: 'pficon pficon-delete fa-lg',
            actionFunction: _.bind(function() {
              const selectedItems = this.data.filter(function(item) {return item.selected});
              if (selectedItems) {
                _.each(selectedItems, function(oneItem) {
                  console.log('You wanted to remove provider with ID: ' + oneItem.id);
                });
              }
            }, this)
        }]
      }, {
        title: __('Policy'),
        icon: 'fa fa-shield fa-lg',
        disabled: true,
        children: [{
          title: __('Edit Tags'),
          disabled: true,
          icon: 'pficon pficon-edit fa-lg',
          actionFunction: _.bind(function() {
            // /ems_middleware/button?pressed=ems_middleware_tag form with selected ids
            window.location = '/ems_middleware/tagging_edit?db=ManageIQ%3A%3AProviders%3A%3AMiddlewareManager&escape=false';
          }, this)
        }]
      }
    ]
}]);
