var dialogFieldRefresh = {
  listenForAutoRefreshMessages: function(fieldId, callbackFunction) {
    window.addEventListener('message', function(event) {
      if (event.data.fieldId !== fieldId) {
        callbackFunction.call();
      }
    });
  },

  refreshCheckbox: function(fieldName, fieldId) {
    miqSparkleOn();

    $.post('dynamic_checkbox_refresh', {name: fieldName}, function(data) {
      $('.dynamic-checkbox-' + fieldId).prop('checked', data.values.checked);
      miqSparkle(false);
    });
  },

  refreshDateTime: function(fieldName, fieldId) {
    miqSparkleOn();

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
    miqSparkleOn();

    $.post('dynamic_radio_button_refresh', {name: fieldName, checked_value: selectedValue}).done(function(data) {
      dialogFieldRefresh.addOptionsToDropDownList(data, fieldId);
    });
  },

  addOptionsToDropDownList: function(data, fieldId) {
    var dropdownOptions = [];

    $.each(data.values.refreshed_values, function(index, value) {
      var option = '<option ';
      option += 'value="' + value[0] + '" ';
      if (data.values.checked_value !== null) {
        if (value[0] !== null) {
          if (data.values.checked_value.toString() === value[0].toString()) {
            option += 'selected="selected" ';
          }
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
  },

  refreshRadioList: function(fieldName, fieldId, checkedValue, onClickString) {
    miqSparkleOn();

    $.post('dynamic_radio_button_refresh', {name: fieldName, checked_value: checkedValue}, function(data) {
      var radioButtons = [];

      $.each(data.values.refreshed_values, function(index, value) {
        var radio = '<input type="radio" ';
        radio += 'id="' + fieldId + '" ';
        radio += 'value="' + value[0] + '" ';
        radio += 'name="' + fieldName + '" ';
        if (data.values.checked_value === value[0].toString()) {
          radio += 'checked="" ';
        }

        if (data.values.read_only === true) {
          radio += 'title="This element is disabled because it is read only" ';
          radio += 'disabled=true ';
        } else {
          radio += onClickString;
        }
        radio += '/> ';
        radio += $('<label></label>').addClass('dynamic-radio-label').text(value[1]).prop('outerHTML');
        radio += ' ';
        radioButtons.push(radio);
      });

      $('#dynamic-radio-' + fieldId).html(radioButtons);

      miqSparkle(false);
    });
  },

  refreshTextAreaBox: function(fieldName, fieldId) {
    miqSparkleOn();

    $.post('dynamic_text_box_refresh', {name: fieldName}, function(data) {
      $('.dynamic-text-area-' + fieldId).val(data.values.text);
      miqSparkle(false);
    });
  },

  refreshTextBox: function(fieldName, fieldId) {
    miqSparkleOn();

    $.post('dynamic_text_box_refresh', {name: fieldName}, function(data) {
      $('.dynamic-text-box-' + fieldId).val(data.values.text);
      miqSparkle(false);
    });
  },

  triggerAutoRefresh: function(fieldId, trigger) {
    if (trigger === "true") {
      parent.postMessage({fieldId: fieldId}, '*');
    }
  }
};
