(function() {
  'use strict';

  angular.module('app.states')
    .run(appRun);

  /** @ngInject */
  function appRun(routerHelper) {
    routerHelper.configureStates(getStates());
  }

  function getStates() {
    return {
      'marketplace.details': {
        url: '/:serviceTemplateId',
        templateUrl: 'app/states/marketplace/details/details.html',
        controller: StateController,
        controllerAs: 'vm',
        title: 'Service Template Details',
        resolve: {
          dialogs: resolveDialogs,
          serviceTemplate: resolveServiceTemplate
        }
      }
    };
  }

  /** @ngInject */
  function resolveServiceTemplate($stateParams, CollectionsApi) {
    var options = {attributes: ['picture', 'picture.image_href']};

    return CollectionsApi.get('service_templates', $stateParams.serviceTemplateId, options);
  }

  /** @ngInject */
  function resolveDialogs($stateParams, CollectionsApi) {
    var options = {expand: 'resources', attributes: 'content'};

    return CollectionsApi.query('service_templates/' + $stateParams.serviceTemplateId + '/service_dialogs', options);
  }

  /** @ngInject */
  function StateController($state, CollectionsApi, dialogs, serviceTemplate, Notifications, DialogFieldRefresh) {
    var vm = this;

    vm.title = 'Service Template Details';
    vm.serviceTemplate = serviceTemplate;

    if (dialogs.subcount > 0) {
      vm.dialogs = dialogs.resources[0].content;
    }

    vm.submitDialog = submitDialog;

    var autoRefreshableDialogFields = [];
    var allDialogFields = [];

    angular.forEach(vm.dialogs, function(dialog) {
      angular.forEach(dialog.dialog_tabs, function(dialogTab) {
        angular.forEach(dialogTab.dialog_groups, function(dialogGroup) {
          angular.forEach(dialogGroup.dialog_fields, function(dialogField) {
            allDialogFields.push(dialogField);
            if (dialogField.default_value === '' && dialogField.values !== '') {
              dialogField.default_value = dialogField.values;
            }

            if (typeof (dialogField.values) === 'object' && dialogField.default_value === undefined) {
              dialogField.default_value = String(dialogField.values[0][0]);
            }

            dialogField.triggerAutoRefresh = function() {
              DialogFieldRefresh.triggerAutoRefresh(dialogField);
            };

            if (dialogField.auto_refresh === true) {
              autoRefreshableDialogFields.push(dialogField.name);
            }
          });
        });
      });
    });

    var dialogUrl = 'service_catalogs/' + serviceTemplate.service_template_catalog_id + '/service_templates';

    angular.forEach(allDialogFields, function(dialogField) {
      dialogField.refreshSingleDialogField = function() {
        DialogFieldRefresh.refreshSingleDialogField(allDialogFields, dialogField, dialogUrl, vm.serviceTemplate.id);
      };
    });

    DialogFieldRefresh.listenForAutoRefreshMessages(
      allDialogFields,
      autoRefreshableDialogFields,
      dialogUrl,
      vm.serviceTemplate.id
    );

    function submitDialog() {
      var dialogFieldData = {
        href: '/api/service_templates/' + serviceTemplate.id
      };

      angular.forEach(allDialogFields, function(dialogField) {
        dialogFieldData[dialogField.name] = dialogField.default_value;
      });

      CollectionsApi.post(
        dialogUrl,
        serviceTemplate.id,
        {},
        JSON.stringify({action: 'order', resource: dialogFieldData})
      ).then(submitSuccess, submitFailure);

      function submitSuccess(result) {
        Notifications.success(result.message);
        $state.go('requests.list');
      }

      function submitFailure(result) {
        Notifications.error('There was an error submitting this request: ' + result);
      }
    }
  }
})();
