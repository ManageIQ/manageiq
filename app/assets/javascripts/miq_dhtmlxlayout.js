// Functions used by MIQ for the dhtmlxlayout control

// Handle splitter bar resize
function miqOnPanelResize() {
  var url = "/" + ManageIQ.controller + "/x_settings_changed/?width=" + this.cells("a").getWidth();
  miqJqueryRequest(url);
}

// When right explorer cell is resized, make toolbar taller or shorter if divs have moved up/down
function miqResizeTaskbarCell() {
  // Make sure everything's here that we need
  if (ManageIQ.toolbars === null || $('#taskbar_buttons_div') == "undefined" || ManageIQ.layout.toolbar === null) {
    return;
  }
  $('#taskbar_buttons_div').children('div').each(function () {
    if (this.offsetTop > 1) {
      ManageIQ.layout.toolbar.height(64);
      return false;
    } else {
      ManageIQ.layout.toolbar.height(32);
    }
  });
}
