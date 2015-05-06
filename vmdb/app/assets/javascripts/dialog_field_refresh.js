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

  refreshDropDownList: function(fieldName, fieldId, selectedValue) {
    miqSparkle(true);

    $.post('dynamic_radio_button_refresh', {name: fieldName, checked_value: selectedValue}, function(data) {
      var dropdownOptions = [];

      $.each(data.values.refreshed_values, function(index, value) {
        var option = '<option ';
        option += 'value="' + value[0] + '" ';
        if (data.values.checked_value !== null) {
          if (data.values.checked_value.toString() === value[0].toString()) {
            option += 'selected="selected" ';
          }
        } else {
          if (index === 0) {
            option += 'selected="selected" ';
          }
        }
        option += '> ' + value[1] + '</option>';
        dropdownOptions.push(option);
      });

      $('.dynamic-drop-down-' + fieldId).html(dropdownOptions);

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
