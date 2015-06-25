ManageIQ.angularApplication.service('miqService', function() {
  this.showButtons = function() {
    miqButtons('show');
  };

  this.hideButtons = function() {
    miqButtons('hide');
  };

  this.buildCalendar = function(year, month, date) {
    ManageIQ.calendar.calDateFrom = new Date(year, month, date);
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

  this.canValidate = function (form, prefix) {
    if (this.validateFieldsValid(form, prefix) && this.validateFieldsDirty(form, prefix))
      return true;
    else
      return false;
  }

  this.canValidateBasicInfo = function () {
    if (ManageIQ.angularApplication.$scope.isBasicInfoValid())
      return true;
    else
      return false;
  }

  this.validateFieldsValid = function (form, prefix) {
    if (form != undefined) {
      if (prefix == "log") {
        if (form.depot_name.$valid &&
            form.uri.$valid &&
            form[prefix + '_userid'].$valid &&
            form[prefix + '_password'].$valid &&
            form[prefix + '_verify'].$valid)
          return true;
      } else {
        if (form[prefix + '_userid'].$valid &&
            form[prefix + '_password'].$valid &&
            form[prefix + '_verify'].$valid)
          return true;
      }
    } else
      return false;
  }

  this.validateFieldsDirty = function (form, prefix) {
    if (form != undefined) {
      if (prefix == "log") {
        if (form.depot_name.$dirty ||
            form.uri.$dirty ||
            form[prefix + '_userid'].$dirty ||
            form[prefix + '_password'].$dirty ||
            form[prefix + '_verify'].$dirty)
          return true;
      } else {
        if (form[prefix + '_userid'].$dirty ||
            form[prefix + '_password'].$dirty ||
            form[prefix + '_verify'].$dirty)
          return true;
      }
    } else
      return false;
  }

   this.validateClicked = function (url) {
     this.sparkleOn();
     this.miqAjaxButton(url, true);
  };

  this.serializeModel = function(model) {
    serializedObj = angular.copy( model );
    for(var k in serializedObj){

      if(serializedObj.hasOwnProperty(k) && !serializedObj[k]){
        delete serializedObj[k];
      }
    }
    return serializedObj;
  }
});
