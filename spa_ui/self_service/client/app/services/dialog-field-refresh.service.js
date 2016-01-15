(function() {
  'use strict';

  angular.module('app.services')
    .factory('DialogFieldRefresh', DialogFieldRefreshFactory);

  /** @ngInject */
  function DialogFieldRefreshFactory(CollectionsApi, Notifications) {
    var service = {
      listenForAutoRefreshMessages: listenForAutoRefreshMessages,
      refreshSingleDialogField: refreshSingleDialogField,
      triggerAutoRefresh: triggerAutoRefresh
    };

    return service;

    function listenForAutoRefreshMessages(allDialogFields, autoRefreshableDialogFields, url, serviceTemplateId) {
      window.addEventListener('message', function(event) {
        var dialogFieldsToRefresh = autoRefreshableDialogFields.filter(function(fieldName) {
          if (event.data.fieldName !== fieldName) {
            return fieldName;
          }
        });

        refreshMultipleDialogFields(allDialogFields, dialogFieldsToRefresh, url, serviceTemplateId);
      });
    }

    function refreshSingleDialogField(allDialogFields, dialogField, url, serviceTemplateId) {
      function refreshSuccess(result) {
        var resultObj = result.result[dialogField.name];

        updateAttributesForDialogField(dialogField, resultObj);
        triggerAutoRefresh(dialogField);
      }

      function refreshFailure(result) {
        Notifications.error('There was an error refreshing this dialog: ' + result);
      }

      fetchDialogFieldInfo(allDialogFields, [dialogField.name], url, serviceTemplateId, refreshSuccess, refreshFailure);
    }

    function triggerAutoRefresh(dialogField) {
      if (dialogField.trigger_auto_refresh === true) {
        parent.postMessage({fieldName: dialogField.name}, '*');
      }
    }

    // Private

    function refreshMultipleDialogFields(allDialogFields, fieldNamesToRefresh, url, serviceTemplateId) {
      function refreshSuccess(result) {
        angular.forEach(allDialogFields, function(dialogField) {
          if (fieldNamesToRefresh.indexOf(dialogField.name) > -1) {
            var resultObj = result.result[dialogField.name];
            updateAttributesForDialogField(dialogField, resultObj);
          }
        });
      }

      function refreshFailure(result) {
        Notifications.error('There was an error automatically refreshing dialogs' + result);
      }

      fetchDialogFieldInfo(allDialogFields, fieldNamesToRefresh, url, serviceTemplateId, refreshSuccess, refreshFailure);
    }

    function updateAttributesForDialogField(dialogField, newDialogField) {
      copyDynamicAttributes(dialogField, newDialogField);

      if (typeof (newDialogField.values) === 'object') {
        dialogField.values = newDialogField.values;
        dialogField.default_value = newDialogField.default_value;
      } else {
        dialogField.default_value = newDialogField.values;
      }

      function copyDynamicAttributes(currentDialogField, newDialogField) {
        currentDialogField.data_type = newDialogField.data_type;
        currentDialogField.options   = newDialogField.options;
        currentDialogField.read_only = newDialogField.read_only;
        currentDialogField.required  = newDialogField.required;
      }
    }

    function fetchDialogFieldInfo(allDialogFields, dialogFieldsToFetch, url, serviceTemplateId, successCallback, failureCallback) {
      CollectionsApi.post(
        url,
        serviceTemplateId,
        {},
        JSON.stringify({
          action: 'refresh_dialog_fields',
          resource: {
            dialog_fields: dialogFieldInfoToSend(allDialogFields),
            fields: dialogFieldsToFetch
          }
        })
      ).then(successCallback, failureCallback);
    }

    function dialogFieldInfoToSend(allDialogFields) {
      var fieldValues = {};
      angular.forEach(allDialogFields, function(dialogField) {
        fieldValues[dialogField.name] = dialogField.default_value;
      });

      return fieldValues;
    }
  }
})();
