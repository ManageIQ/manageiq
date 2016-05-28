/* global miqAjaxButton miqBuildCalendar miqButtons miqJqueryRequest miqRESTAjaxButton miqSparkleOff miqSparkleOn */

ManageIQ.angular.app.service('miqService', function() {

  this.storedPasswordPlaceholder = "●●●●●●●●";

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

  this.restAjaxButton = function(url, button, data) {
    miqRESTAjaxButton(url, button, data);
  };

  this.jqueryRequest = function(url, options) {
    miqJqueryRequest(url, options);
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
    var outerMost = $("<div id='flash_text_div' onclick=$('#flash_msg_div').text(''); title='" + __("Click to remove messages") + "'>");
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

  this.validateWithAjax = function (url) {
    miqSparkleOn();
    miqAjaxButton(url, true);
  };

  this.validateWithREST = function($event, credType, url, formSubmit) {
    angular.element('#button_name').val('validate');
    angular.element('#cred_type').val(credType);
    if(formSubmit) {
      miqSparkleOn();
      miqRESTAjaxButton(url, $event.target);
    }
    else {
      $event.preventDefault();
    }
  };

  this.disabledClick = function($event) {
    $event.preventDefault();
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
