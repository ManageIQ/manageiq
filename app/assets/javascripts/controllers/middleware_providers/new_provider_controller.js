(function(){
  /**
  * Define default actions on form.
  * It requires to have bound object with  saveAction and onBackToListClick functions.
  */
  var defaultActions = function() {
    return [{
      btnClass: 'btn-primary',
      title: __('Add this Middleware Manager'),
      validate: true,
      clickFunction: function(){
        this.saveAction();
      }.bind(this),
      label: __('Add')
    }, {
      btnClass: 'btn-default',
      title: __('Cancel and return to list of Middleware providers'),
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
  }

  /**
  * Constructor for NewProviderController.
  * @param $location location service.
  * @param MiQFormValidatorService form validator service.
  * @param MiQNotificationService notification service.
  */
  var NewProviderController = function($location, MiQFormValidatorService, MiQNotificationService) {
    this.$location = $location;
    this.MiQFormValidatorService = MiQFormValidatorService;
    this.MiQNotificationService = MiQNotificationService;

    this.formActions = defaultActions.bind(this)();
    this.credentialsTabs = setCredentialsTab.bind(this)();

    this.types = [__('Hawkular')];

    this.zones = [__('Dan'), __('Dan 2 Zone'), __('Default Zone'), __('RHEV 1 for fleecing')];

    this.newProvider = {
      type: 'default',
      zone: __('Default Zone'),
      remoteLogin: {},
      webServices: {},
      impi: {}
    };
  };

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
    this.MiQFormValidatorService.validateObject(this.newProvider).then(function(formResponseData){
      this.validateFunction(formResponseData, loadingItem);
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
      item.hostname = item.hostname.replace(/.*?:\/\//g, "");
      if (item.hostname.lastIndexOf('/') === item.hostname.length - 1) {
        item.hostname = item.hostname.slice(0,-1);
      }
    }
  };

  /**
  * Method for redirecting back to showing list of data.
  */
  NewProviderController.prototype.onBackToListClick = function() {
    this.$location.path('/ems_middleware/show_list/list');
    this.MiQNotificationService.sendSuccess(
      this.MiQNotificationService.dismissibleMessage(__('Validation Successfull'))
    );
  };

  NewProviderController.$inject = ['$location', 'MiQFormValidatorService', 'MiQNotificationService'];
  miqHttpInject(angular.module('middleware.provider'))
  .controller('miqNewProviderController', NewProviderController);
})()
