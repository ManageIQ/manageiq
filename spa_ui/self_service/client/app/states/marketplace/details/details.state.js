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
  function StateController($state, CollectionsApi, dialogs, serviceTemplate, Notifications) {
    var vm = this;

    vm.title = 'Service Template Details';
    vm.serviceTemplate = serviceTemplate;

    if (dialogs.subcount > 0) {
      vm.dialogs = dialogs.resources[0].content;
    }

    vm.submitDialog = submitDialog;

    var autoRefreshableDialogFields = [];
    vm.dialogFields = [];

    angular.forEach(vm.dialogs, function(dialog) {
      angular.forEach(dialog.dialog_tabs, function(dialogTab) {
        angular.forEach(dialogTab.dialog_groups, function(dialogGroup) {
          angular.forEach(dialogGroup.dialog_fields, function(dialogField) {
            vm.dialogFields.push(dialogField);
            dialogField.refreshSingleDialogField = refreshSingleDialogField;
            dialogField.triggerAutoRefresh = triggerAutoRefresh;
            if (dialogField.auto_refresh === true) {
              autoRefreshableDialogFields.push(dialogField.name);
            }
          });
        });
      });
    });

    listenForAutoRefreshMessages();

    function listenForAutoRefreshMessages(fromDialogFieldId, fromDialogFieldName) {
      window.addEventListener('message', function(event) {
        var dialogFieldsToRefresh = autoRefreshableDialogFields.filter(function(fieldName) {
          if (event.data.fieldName !== fieldName) {
            return fieldName;
          }
        });

        refreshMultipleDialogFields(dialogFieldsToRefresh);
      });
    }

    function submitDialog() {
      var dialogFieldData = {
        href: '/api/service_templates/' + serviceTemplate.id
      };

      angular.forEach(vm.dialogFields, function(dialogField) {
        dialogFieldData[dialogField.name] = dialogField.default_value;
      });

      CollectionsApi.post(
        'service_catalogs/' + serviceTemplate.service_template_catalog_id + '/service_templates',
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

    function refreshSingleDialogField(dialogField) {
      function refreshSuccess(result) {
        var resultObj = result.result[dialogField.name];

        updateAttributesForDialogField(dialogField, resultObj);
        dialogField.triggerAutoRefresh(dialogField);
      }

      function refreshFailure(result) {
        Notifications.error('There was an error refreshing this dialog: ' + result);
      }

      fetchDialogFieldInfo([dialogField.name], refreshSuccess, refreshFailure);
    }

    function triggerAutoRefresh(dialogField) {
      if (dialogField.trigger_auto_refresh === true) {
        parent.postMessage({fieldName: dialogField.name}, '*');
      }
    }

    function updateAttributesForDialogField(dialogField, newDialogField) {
      copyDynamicAttributes(dialogField, newDialogField);

      if (typeof(newDialogField.values) === 'object') {
        dialogField.values = newDialogField.values;
        dialogField.default_value = newDialogField.default_value;
      } else {
        dialogField.default_value = newDialogField.values;
      }

      function copyDynamicAttributes(current_dialog_field, new_dialog_field) {
        current_dialog_field.data_type = new_dialog_field.data_type;
        current_dialog_field.options   = new_dialog_field.options;
        current_dialog_field.read_only = new_dialog_field.read_only;
        current_dialog_field.required  = new_dialog_field.required;
      }
    }

    function refreshMultipleDialogFields(fieldNamesToRefresh) {
      function refreshSuccess(result) {
        angular.forEach(vm.dialogFields, function(dialogField) {
          if (fieldNamesToRefresh.indexOf(dialogField.name) > -1) {
            var resultObj = result.result[dialogField.name];
            updateAttributesForDialogField(dialogField, resultObj);
          }
        });
      }

      function refreshFailure(result) {
        Notifications.error('There was an error automatically refreshing dialogs' + result);
      }

      var fieldValues = {};
      angular.forEach(vm.dialogFields, function(dialogField) {
        fieldValues[dialogField.name] = dialogField.value;
      });

      fetchDialogFieldInfo(fieldNamesToRefresh, refreshSuccess, refreshFailure);
    }

    function fetchDialogFieldInfo(dialogFieldsToFetch, successCallback, failureCallback) {
      CollectionsApi.post(
        'service_catalogs/' + serviceTemplate.service_template_catalog_id + '/service_templates',
        serviceTemplate.id,
        {},
        JSON.stringify({
          action: 'refresh_dialog_fields',
          resource: {
            dialog_fields: dialogFieldInfoToSend(),
            fields: dialogFieldsToFetch
          }
        })
      ).then(successCallback, failureCallback);
    }

    function dialogFieldInfoToSend() {
      var fieldValues = {};
      angular.forEach(vm.dialogFields, function(dialogField) {
        fieldValues[dialogField.name] = dialogField.default_value;
      });

      return fieldValues;
    }
  }
})();
