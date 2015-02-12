cfmeAngularApplication.service('miqService', function() {
  this.showButtons = function() {
    miqButtons('show');
  };

  this.hideButtons = function() {
    miqButtons('hide');
  };

  this.buildCalendar = function(year, month, date) {
    miq_cal_dateFrom = new Date(year, month, date);
    miqBuildCalendar(true);
  };

  this.miqAjaxButton = function(url, serializeFields) {
    miqAjaxButton(url, serializeFields);
  };

  this.sparkleOn = function() {
    miqSparkleOn();
  };

  this.sparkleOff = function() {
    miqSparkleOff();
  };

  this.miqFlash = function(type, msg) {
    $('#flash_msg_div').text("");
    $("#flash_msg_div").show();
    var outerMost = $("<div id='flash_text_div' onclick=$('#flash_msg_div').text(''); title='Click to remove messages'>");
    var txt = $('<strong>' + msg + '</strong>');

    if(type == "error") {
      var outerBox = $('<div class="alert alert-danger">');
      var innerSpan = $('<span class="pficon-layered">');
      var icon1 = $('<span class="pficon pficon-error-octagon">');
      var icon2 = $('<span class="pficon pficon-warning-exclamation">');

      $(innerSpan).append(icon1);
      $(innerSpan).append(icon2);
    } else if(type == "warn")
    {
      var outerBox = $('<div class="alert alert-warning">');
      var innerSpan = $('<span class="pficon-layered">');
      var icon1 = $('<span class="pficon pficon-warning-triangle">');
      var icon2 = $('<span class="pficon pficon-warning-exclamation">');

      $(innerSpan).append(icon1);
      $(innerSpan).append(icon2);
    } else if(type == "success")
    {
      var outerBox = $('<div class="alert alert-success">');
      var innerSpan = $('<span class="pficon pficon-ok">');
    }
      $(outerBox).append(innerSpan);
      $(outerBox).append(txt);
      $(outerMost).append(outerBox);
      $(outerMost).appendTo($("#flash_msg_div"));
  }

  this.miqFlashClear = function() {
    $('#flash_msg_div').text("");
  }

  this.saveable = function(form) {
    return form.$valid && form.$dirty;
  };

  this.canValidate = function (form) {
    if (this.validateFieldsValid(form) && this.validateFieldsDirty(form))
      return true;
    else
      return false;
  }

  this.validateFieldsValid = function (form) {
    if (form != undefined &&
      form.depot_name.$valid &&
      form.uri.$valid &&
      form.log_userid.$valid &&
      form.log_password.$valid &&
      form.log_verify.$valid)
      return true;
    else
      return false;
  }

  this.validateFieldsDirty = function (form) {
    if (form != undefined &&
      form.depot_name.$dirty ||
      form.uri.$dirty ||
      form.log_userid.$dirty ||
      form.log_password.$dirty ||
      form.log_verify.$dirty)
      return true;
    else
      return false;
  }
});
