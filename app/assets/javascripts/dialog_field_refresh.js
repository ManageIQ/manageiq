/* global miqInitSelectPicker miqSelectPickerEvent miqSparkle miqSparkleOn */

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

    var data = {name: fieldName};
    var doneFunction = function(data) {
      var responseData = JSON.parse(data.responseText);
      $('.dynamic-checkbox-' + fieldId).prop('checked', responseData.values.checked);
      dialogFieldRefresh.setReadOnly($('.dynamic-checkbox-' + fieldId), responseData.values.read_only);
    };

    dialogFieldRefresh.sendRefreshRequest('dynamic_checkbox_refresh', data, doneFunction);
    $.post('dynamic_checkbox_refresh', {name: fieldName}, function(data) {
      $('.dynamic-checkbox-' + fieldId).prop('checked', data.values.checked);
      dialogFieldRefresh.setReadOnly($('.dynamic-checkbox-' + fieldId), data.values.read_only);
      dialogFieldRefresh.setVisible($('.dynamic-checkbox-' + fieldId), data.values.visible);
      miqSparkle(false);
    });
  },

  refreshDateTime: function(fieldName, fieldId) {
    miqSparkleOn();

    var data = {name: fieldName};
    var doneFunction = function(data) {
      var responseData = JSON.parse(data.responseText);
      $('.dynamic-date-' + fieldId).val(responseData.values.date);

      if (responseData.values.hour !== undefined && responseData.values.min !== undefined) {
        $('.dynamic-date-hour-' + fieldId).val(responseData.values.hour);
        $('.dynamic-date-min-' + fieldId).val(responseData.values.min);
      }

      dialogFieldRefresh.setReadOnly($('.dynamic-date-' + fieldId), data.values.read_only);
      dialogFieldRefresh.setVisible($('.dynamic-date-' + fieldId), data.values.visible);

    dialogFieldRefresh.sendRefreshRequest('dynamic_date_refresh', data, doneFunction);
  },

  refreshDropDownList: function(fieldName, fieldId, selectedValue) {
    miqSparkleOn();
    var data = {name: fieldName, checked_value: selectedValue};
    var doneFunction = function(data) {
      var responseData = JSON.parse(data.responseText);
      dialogFieldRefresh.addOptionsToDropDownList(responseData, fieldId);
      dialogFieldRefresh.setReadOnly($('#' + fieldName), responseData.values.read_only);

    $.post('dynamic_radio_button_refresh', {
      name: fieldName,
      checked_value: selectedValue,
    })
    .done(function(data) {
      dialogFieldRefresh.addOptionsToDropDownList(data, fieldId);
      dialogFieldRefresh.setReadOnly($('#' + fieldName), data.values.read_only);
<<<<<<< 36a2a7ef2d40bb274b1e2c63352f722c57706804
      dialogFieldRefresh.setVisible($('#' + fieldName), data.values.visible);
=======
      dialogFieldRefresh.setVisible($('#field_' + fieldId + "_tr"), data.values.visible, fieldId);
      $('#' + fieldName).selectpicker('refresh');
      $('#' + fieldName).selectpicker('val', data.values.checked_value);
    });
  },
>>>>>>> Add visible to all dialog field automate methods

      $('#' + fieldName).selectpicker('refresh');
      $('#' + fieldName).selectpicker('val', responseData.values.checked_value);
    };

    dialogFieldRefresh.sendRefreshRequest('dynamic_radio_button_refresh', data, doneFunction);
  },

  refreshRadioList: function(fieldName, fieldId, checkedValue, onClickString) {
    miqSparkleOn();

    var data = {name: fieldName, checked_value: checkedValue};
    var doneFunction = function(data) {
      var responseData = JSON.parse(data.responseText);
      var radioButtons = [];

      $.each(responseData.values.refreshed_values, function(_index, value) {
        var radio = $('<input>')
          .attr('id', fieldId)
          .attr('name', fieldName)
          .attr('type', 'radio')
          .val(value[0]);

        var label = $('<label></label>')
          .addClass('dynamic-radio-label')
          .text(value[1]);

        if (responseData.values.checked_value === String(value[0])) {
          radio.prop('checked', true);
        }

        if (responseData.values.read_only === true) {
          radio.attr('title', __("This element is disabled because it is read only"));
          radio.prop('disabled', true);
        } else {
          radio.on('click', onClickString);
        }

        radioButtons.push(radio);
        radioButtons.push(" ");
        radioButtons.push(label);
        radioButtons.push(" ");
      });

      $('#dynamic-radio-' + fieldId).html(radioButtons);
    };

    dialogFieldRefresh.sendRefreshRequest('dynamic_radio_button_refresh', data, doneFunction);
  },

  refreshTextAreaBox: function(fieldName, fieldId) {
    miqSparkleOn();

    var data = {name: fieldName};
    var doneFunction = function(data) {
      var responseData = JSON.parse(data.responseText);
      $('.dynamic-text-area-' + fieldId).val(responseData.values.text);
      dialogFieldRefresh.setReadOnly($('.dynamic-text-area-' + fieldId), responseData.values.read_only);
    };

    dialogFieldRefresh.sendRefreshRequest('dynamic_text_box_refresh', data, doneFunction);
    $.post('dynamic_text_box_refresh', {name: fieldName}, function(data) {
      $('.dynamic-text-area-' + fieldId).val(data.values.text);
      dialogFieldRefresh.setReadOnly($('.dynamic-text-area-' + fieldId), data.values.read_only);
      dialogFieldRefresh.setVisible($('.dynamic-text-area-' + fieldId), data.values.visible);
      miqSparkle(false);
    });

  refreshTextBox: function(fieldName, fieldId) {
    miqSparkleOn();

    var data = {name: fieldName};
    var doneFunction = function(data) {
      var responseData = JSON.parse(data.responseText);
      $('.dynamic-text-box-' + fieldId).val(responseData.values.text);
      dialogFieldRefresh.setReadOnly($('.dynamic-text-box-' + fieldId), responseData.values.read_only);
    };

    dialogFieldRefresh.sendRefreshRequest('dynamic_text_box_refresh', data, doneFunction);
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
      } else if (index === 0) {
        option.prop('selected', true);
      }

      dropdownOptions.push(option);
    $.post('dynamic_text_box_refresh', {name: fieldName}, function(data) {
      $('.dynamic-text-box-' + fieldId).val(data.values.text);
      dialogFieldRefresh.setReadOnly($('.dynamic-text-box-' + fieldId), data.values.read_only);
      dialogFieldRefresh.setVisible($('.dynamic-text-box-' + fieldId), data.values.visible);
      miqSparkle(false);
    });

    $('.dynamic-drop-down-' + fieldId + '.selectpicker').html(dropdownOptions);
    $('.dynamic-drop-down-' + fieldId + '.selectpicker').selectpicker('refresh');
  },


  triggerAutoRefresh: function(fieldId, trigger) {
    if (trigger === "true") {
      parent.postMessage({fieldId: fieldId}, '*');
    }
  },

  setReadOnly: function(field, readOnly) {
    if (readOnly === true) {
      field.attr('title', __('This element is disabled because it is read only'));
      field.prop('disabled', true);
    } else {
      field.prop('disabled', false);
      field.attr('title', '');
    }
  },

  sendRefreshRequest: function(url, data, doneFunction) {
    miqJqueryRequest(url, {
      data: data,
      dataType: 'json',
      beforeSend: true,
      complete: true,
      done: doneFunction
    });

  setVisible: function(field, visible) {
    if (visible === true) {
      field.show();
    } else {
      field.hide();
    }
  }
};
