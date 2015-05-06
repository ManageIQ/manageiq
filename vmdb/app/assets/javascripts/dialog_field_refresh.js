var dialogFieldRefresh = {
  listenForAutoRefreshMessages: function(fieldId, callbackFunction) {
    window.addEventListener('message', function(event) {
      if (event.data.fieldId !== fieldId) {
        callbackFunction.call();
      }
    });
  },

  refreshCheckbox: function(fieldName, fieldId) {
    miqSparkle(true);

    $.post('dynamic_checkbox_refresh', {name: fieldName}, function(data) {
      $('.dynamic-checkbox-' + fieldId).prop('checked', data.values.checked);
      miqSparkle(false);
    });
  },

  refreshDateTime: function(fieldName, fieldId) {
    miqSparkle(true);

    $.post('dynamic_date_refresh', {name: fieldName}, function(data) {
      $('.dynamic-date-' + fieldId).val(data.values.date);

      if (data.values.hour !== undefined && data.values.min !== undefined) {
        $('.dynamic-date-hour-' + fieldId).val(data.values.hour);
        $('.dynamic-date-min-' + fieldId).val(data.values.min);
      }

      miqSparkle(false);
    });
  },

  refreshTextAreaBox: function(fieldName, fieldId) {
    miqSparkle(true);

    $.post('dynamic_text_box_refresh', {name: fieldName}, function(data) {
      $('.dynamic-text-area-' + fieldId).val(data.values.text);
      miqSparkle(false);
    });
  },

  refreshTextBox: function(fieldName, fieldId) {
    miqSparkle(true);

    $.post('dynamic_text_box_refresh', {name: fieldName}, function(data) {
      $('.dynamic-text-box-' + fieldId).val(data.values.text);
      miqSparkle(false);
    });
  },

  triggerAutoRefresh: function(fieldId) {
    parent.postMessage({fieldId: fieldId}, '*');
  }
};
