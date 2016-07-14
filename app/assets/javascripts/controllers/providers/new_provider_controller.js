(function(){
  /**
  * Define default actions on form.
  * It requires to have bound object with  saveAction and onBackToListClick functions.
  */
  var defaultActions = function() {
    return [{
      btnClass: 'btn-primary',
      title: __('Add this Manager'),
      validate: true,
      clickFunction: function(){
        this.saveAction();
      }.bind(this),
      label: __('Add')
    }, {
      btnClass: 'btn-default',
      title: __('Cancel and return to list of providers'),
      clickFunction: function(){
        this.onBackToListClick();
      }.bind(this),
      label: __('Cancel')
    }];
  }

  /**
  * Define credentials items.
  */
  var setCredentialsTab = function() {
    return [{
      title: __('Default'),
      description: __('Required. Should have privileged access, such as root or administrator.'),
      modelKey: 'default'
    }];
  }

  /**
  * Constructor for NewProviderController.
  * @param $location location service.
  * @param MiQFormValidatorService form validator service.
  * @param MiQNotificationService notification service.
  * @param $timeout service for setTimeout over angular.
  */
  var NewProviderController = function(
    MiQFormValidatorService,
    MiQNotificationService,
    $timeout,
    $state,
    MiQNewProviderStateService,
    MiQProvidersSettingsService,
    MiQEndpointsService
  ) {
    this.$state = $state;
    this.MiQFormValidatorService = MiQFormValidatorService;
    this.MiQNotificationService = MiQNotificationService;
    this.MiQProvidersSettingsService = MiQProvidersSettingsService;
    this.$timeout = $timeout;
    this.MiQNewProviderStateService = MiQNewProviderStateService;
    this.MiQEndpointsService = MiQEndpointsService;

    this.initEndpoints();

    this.formActions = defaultActions.bind(this)();
    this.credentialsTabs = setCredentialsTab.bind(this)();

    this.zones = [__('Dan'), __('Dan 2 Zone'), __('Default Zone'), __('RHEV 1 for fleecing')];

    this.newProvider = {
      type: 'default',
      zone: __('Default Zone'),
      remoteLogin: {}
    };
  };

  /**
  * Method which loads additional view based on selected server ems type.
  */
  NewProviderController.prototype.typeSelected = function() {
    if (this.server_emstype) {
      this.newProvider.server_emstype = this.server_emstype.id;
      this.$state.go(this.server_emstype.stateId);
    } else {
      this.$state.go('new_provider');
    }
  }

  /**
  * Action which is called after saving item.
  * It uses angular's promises and calls #saveObject(formResponseData) and #stripProtocol(newProvider).
  */
  NewProviderController.prototype.saveAction = function() {
    this.MiQFormValidatorService.saveObject(this.newProvider).then(function(formResponseData){
      this.stripProtocol(this.newProvider);
      this.saveObject(formResponseData);
    }.bind(this));
  };

  /**
  * Method for showing error messages whith happened on validation or after save.
  * @param formResponseData response data of form.
  * @param loadingItem item which was used for showing spinner.
  */
  NewProviderController.prototype.showErrorMsgs = function(formResponseData, loadingItem) {
    if (formResponseData.errorMsg) {
      this.MiQNotificationService.sendDanger(this.MiQNotificationService.dismissibleMessage(formResponseData.errorMsg, __('Validation Error: '), loadingItem));
    }
    _.each(formResponseData.serverAlerts, function(item, key){
      this.MiQNotificationService.sendDanger(this.MiQNotificationService.dismissibleMessage(item, key, loadingItem));
    }.bind(this));
  };

  /**
  * Method for saving data to server, it will either dava data or show error msgs.
  * @param formResponseData data of form for saving new item.
  */
  NewProviderController.prototype.saveObject = function(formResponseData) {
    var loadingItem = this.MiQNotificationService.sendLoading(
      this.MiQNotificationService.dismissibleMessage(__('Save in progress'))
    );
    if(formResponseData.isValid) {
      this.onBackToListClick();
      this.$timeout(function() {
        this.MiQNotificationService.sendSuccess(
          this.MiQNotificationService.dismissibleMessage(__('Save of new provider Successfull'))
        );
      }.bind(this));
    } else {
      this.showErrorMsgs(formResponseData, loadingItem);
    }
  };

  /**
  * Method for validating credentials and entire form.
  * @param validateData data to be validated.
  */
  NewProviderController.prototype.validateAction = function(validateData) {
    var loadingItem = this.MiQNotificationService.sendLoading(
      this.MiQNotificationService.dismissibleMessage(__('Validation in progress'))
    );
    this.stripProtocol(this.newProvider);
    return this.MiQFormValidatorService.validateObject(this.newProvider).then(function(formResponseData){
      this.validateFunction(formResponseData, loadingItem);
      return formResponseData;
    }.bind(this));
  };

  /**
  * Method for checking if data are valid, either show success function or proceed
  * to show error messages.
  * @param formResponseData data of form.
  * @param loadingItem item which was used for showing that data were loaded from server.
  */
  NewProviderController.prototype.validateFunction = function(formResponseData, loadingItem) {
    if (!formResponseData.isValid) {
      this.showErrorMsgs(formResponseData, loadingItem);
    } else {
      this.MiQNotificationService.sendSuccess(
        this.MiQNotificationService.dismissibleMessage(__('Validation Successfull'), '', loadingItem)
      );
    }
  };

  /**
  * Method for striping down protocol and last '/' from hostname.
  * It will streip https://, http:// ... etc.
  * @param item with hostname property.
  */
  NewProviderController.prototype.stripProtocol = function(item) {
    if (item.hasOwnProperty('hostname')) {
      item.hostname = item.hostname.replace(/.*?:\/\//g, '');
      if (item.hostname.lastIndexOf('/') === item.hostname.length - 1) {
        item.hostname = item.hostname.slice(0,-1);
      }
    }
  };

  /**
  * Method for redirecting back to showing list of data.
  */
  NewProviderController.prototype.onBackToListClick = function() {
    this.$state.go('list_providers');
  };

  /**
  */
  NewProviderController.prototype.mapTemplatesToViews = function() {
    _.each(this.types, function(oneType) {
      oneType.views = _
        .chain(oneType.templates)
        .zipObject(oneType.templates)
        .mapValues(function (item) {
          return '/static' + this.MiQEndpointsService.rootPoint + '/new_provider/' + item + '.html';
        }.bind(this))
        .value();
    }.bind(this));
  }

  /**
  */
  NewProviderController.prototype.loadData = function() {
    this.MiQProvidersSettingsService.getSettings().then(function(providersSettings) {
      this.newProviderTitle = providersSettings.newProvider;
    }.bind(this));

    return this.MiQNewProviderStateService.getProviderTypes('new_provider')
      .then(function(providerTypes) {
          this.types = providerTypes;
          if (!_.find(this.types, 'views') && _.find(this.types, 'templates')) {
            this.mapTemplatesToViews();
          }
          this.MiQNewProviderStateService.addProviderStates(providerTypes);
      }.bind(this))
  };

  NewProviderController.prototype.initEndpoints = function() {
    var urlPrefix = '/' + location.pathname.split('/')[1];
    if (urlPrefix) {
      this.MiQEndpointsService.rootPoint = urlPrefix;  
    }
    this.MiQEndpointsService.endpoints.validateItem = '/validate_provider';
    this.MiQEndpointsService.endpoints.createItem = '/new_provider';
  }

  NewProviderController.$inject = ['MiQFormValidatorService', 'MiQNotificationService',
  '$timeout', '$state', 'MiQNewProviderStateService',
  'MiQProvidersSettingsService', 'MiQEndpointsService'];
  miqHttpInject(angular.module('miq.provider'))
  .controller('miqNewProviderController', NewProviderController);
})()
