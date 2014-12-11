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
    $j('#flash_msg_div').text("");
    $j("#flash_msg_div").show();
    var outerMost = $j("<div id='flash_text_div' onclick=$j('#flash_msg_div').text(''); title='Click to remove messages'>");
    var txt = $j('<strong>' + msg + '</strong>');

    if(type == "error") {
      var outerBox = $j('<div class="alert alert-danger">');
      var innerSpan = $j('<span class="pficon-layered">');
      var icon1 = $j('<span class="pficon pficon-error-octagon">');
      var icon2 = $j('<span class="pficon pficon-warning-exclamation">');

      $j(innerSpan).append(icon1);
      $j(innerSpan).append(icon2);
    } else if(type == "warn")
    {
      var outerBox = $j('<div class="alert alert-warning">');
      var innerSpan = $j('<span class="pficon-layered">');
      var icon1 = $j('<span class="pficon pficon-warning-triangle">');
      var icon2 = $j('<span class="pficon pficon-warning-exclamation">');

      $j(innerSpan).append(icon1);
      $j(innerSpan).append(icon2);
    } else if(type == "success")
    {
      var outerBox = $j('<div class="alert alert-success">');
      var innerSpan = $j('<span class="pficon pficon-ok">');
    }
      $j(outerBox).append(innerSpan);
      $j(outerBox).append(txt);
      $j(outerMost).append(outerBox);
      $j(outerMost).appendTo($j("#flash_msg_div"));
  }
});
