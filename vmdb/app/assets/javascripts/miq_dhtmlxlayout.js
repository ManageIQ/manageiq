// Functions used by MIQ for the dhtmlxlayout control

// Handle splitter bar resize
function miqOnPanelResize(){
//	alert("Resized to " + this.cells("a").getWidth());
	var url = "/" + miq_controller + "/x_settings_changed/?width=" + this.cells("a").getWidth();
  miqJqueryRequest(url);
}

// When right explorer cell is resized, make dhxLayoutB cell "a" taller or shorter if divs have moved up/down
function miqResizeTaskbarCell(){
  if (typeof miq_toolbars == "undefined" || // Make sure everything's here that we need
      $('#taskbar_buttons_div') == "undefined" ||
      typeof dhxLayoutB == "undefined")
    return;
  $('#taskbar_buttons_div').children('div').each(function(){
    if (this.offsetTop > 0) {
      dhxLayoutB.cells("a").setHeight(64);
      return false;
    }
    else
      dhxLayoutB.cells("a").setHeight(32);
  });
}
