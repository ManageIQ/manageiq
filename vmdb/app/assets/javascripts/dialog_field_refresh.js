var dialogFieldRefresh = {
  listenForAutoRefreshMessages: function(fieldId, callbackFunction) {
    window.addEventListener('message', function(event) {
      if (event.data.fieldId !== fieldId) {
        callbackFunction.call();
      }
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
