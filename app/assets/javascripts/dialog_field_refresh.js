var dialogFieldRefresh = {
  listenForAutoRefreshMessages: function(fieldId, callbackFunction) {
    window.addEventListener('message', function(event) {
      if (event.data.fieldId !== fieldId) {
        callbackFunction.call();
      }
    });
  },

  initializeDialogSelectPicker: function(fieldName, fieldId, selectedValue, url, triggerAutoRefresh) {
    miqInitSelectPicker();
    if (selectedValue !== undefined) {
      $('#' + fieldName).selectpicker('val', selectedValue);
    }
    miqSelectPickerEvent(fieldName, url, {callback: function() {
      dialogFieldRefresh.triggerAutoRefresh(fieldId, triggerAutoRefresh || "true");
      return true;
    }});
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

    $.post('dynamic_radio_button_refresh', {
      name: fieldName,
      checked_value: selectedValue,
    })
    .done(function(data) {
      dialogFieldRefresh.addOptionsToDropDownList(data, fieldId);
      $('#' + fieldName).selectpicker('refresh');
      $('#' + fieldName).selectpicker('val', selectedValue);
    });
  },

  addOptionsToDropDownList: function(data, fieldId) {
    var dropdownOptions = [];

    $.each(data.values.refreshed_values, function(index, value) {
      var option = $('<option></option>');

      option.val(value[0]);
      option.text(value[1]);

      if (data.values.checked_value !== null) {
        if (value[0] !== null) {
          if (data.values.checked_value.toString() === String(value[0])) {
            option.prop('selected', true);
          }
        }
      } else {
        if (index === 0) {
          option.prop('selected', true);
        }
      }

      dropdownOptions.push(option);
    });

    $('.dynamic-drop-down-' + fieldId + '.selectpicker').html(dropdownOptions);
    $('.dynamic-drop-down-' + fieldId + '.selectpicker').selectpicker('refresh');

    miqSparkle(false);
  },

  refreshRadioList: function(fieldName, fieldId, checkedValue, onClickString) {
    miqSparkleOn();

    $.post('dynamic_radio_button_refresh', {
      name: fieldName,
      checked_value: checkedValue
    }, function(data) {
      var radioButtons = [];

      $.each(data.values.refreshed_values, function(index, value) {
        var radio = $('<input>')
          .attr('id', fieldId)
          .attr('name', fieldName)
          .attr('type', 'radio')
          .val(value[0]);

        var label = $('<label></label>')
          .addClass('dynamic-radio-label')
          .text(value[1]);

        if (data.values.checked_value === String(value[0])) {
          radio.prop('checked', true);
        }

        if (data.values.read_only === true) {
          radio.attr('title', __("This element is disabled because it is read only"));
          radio.prop('disabled', true);
        } else {
          radio.on('click', new Function(onClickString));
        }

        radioButtons.push(radio);
        radioButtons.push(" ");
        radioButtons.push(label);
        radioButtons.push(" ");
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
