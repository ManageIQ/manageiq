cfmeAngularApplication.service('miqService', function() {
  this.showButtons = function() {
    miqButtons('show');
  };

  this.hideButtons = function() {
    miqButtons('hide');
  };

  this.buildCalendar = function(year, month, date) {
    miq_cal_dateFrom = new Date(year, month, date);
    miqBuildCalendar();
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
});
