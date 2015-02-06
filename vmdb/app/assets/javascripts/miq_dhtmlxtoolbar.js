// Functions used by MIQ for the dhtmlxtoolbar control

// This function is called in miqOnLoad
function miqInitToolbars() {
	if (typeof miq_toolbars == "undefined") return;
  $.each(miq_toolbars, function( key ) {
		miqInitToolbar(miq_toolbars[key]);
	});
//  miqResizeTaskbarCell(); TODO: Commented out when removing outer DHTMLX layout, need to revisit
}

// Initialize a single toolbar
function miqInitToolbar(tb_hash){
	tb = tb_hash['obj'];
	tb.setIconsPath("/images/toolbars/");
	tb.loadXMLString(tb_hash['xml']);
	tb.attachEvent("onClick", miqToolbarOnClick);
//	tb.attachEvent("onStateChange", miqToolbarOnStateChange);
	tb.attachEvent("onStateChange", miqToolbarOnClick);
	miqHideToolbarButtons();
  miqSetToolbarButtonIds(tb);
}

// Set miq_alone class for non-pulldown buttons
function miqSetToolbarButtonIds(tb) {
  tb.forEachItem(function(itemId){
    if (tb.objPull[tb.idPrefix+itemId]["type"] != "buttonSelect"){
      var item = tb.objPull[tb.idPrefix+itemId];
//      item.obj.parentElement.className = item.obj.parentElement.className + " miq_alone"; /*class for parent div around text div*/
      item.obj.id = "miq_alone"; /*class for parent div around text div*/
//      item.arw.className = "..."; /*class for arrow*/
    }
  });
}

// Hide buttons in the toolbars
function miqHideToolbarButtons(){
	if (typeof miq_toolbars['view_tb'] != "undefined") {
		for (var x in miq_toolbars['view_tb']['buttons']) {
			if (view_tb.getType(x) == "button"){
				if (view_tb.getPosition(x)> 0 && miq_toolbars['view_tb']['buttons'][x].hidden) {
					view_tb.hideItem(x);
					view_tb.hideItem('sep_1');
				}
			}
		}
	}
	if (typeof miq_toolbars['center_tb'] != "undefined") {
		var tb = miq_toolbars['center_tb']['obj'];
		var buttons = miq_toolbars['center_tb']['buttons']
		for (var x in buttons) {
			var count = 0
			if (tb.getType(x) == "button"){
				if (tb.getPosition(x)>= 0 && buttons[x].hidden) {
					tb.hideItem(x);
				}
			} else if (tb.getType(x) == "buttonSelect"){
				for (var y in buttons) {
					//Hide any items in the list that is hidden
					if (tb.getListOptionPosition(x,y)> 0 && buttons[y].hidden) {
						tb.hideListOption(x,y);
						count+=1;
					}
					//Hide buttonselect button, if all items under it are hidden
					if (count == tb.getAllListOptions(x).length-1 && tb.getPosition(x)> 0 && buttons[x].hidden) {
						tb.hideItem(x);
					}
					if (tb.getListOptionPosition(x,y)> 0 && typeof buttons[y].title != "undefined") {
						tb.setListOptionToolTip(x, y, buttons[y].title);
					}
				}
			}
		}
	}
  if (typeof miq_toolbars['custom_tb'] != "undefined") {
    var tb = miq_toolbars['custom_tb']['obj'];
    var buttons = miq_toolbars['custom_tb']['buttons']
    for (var x in buttons) {
      var count = 0
      if (tb.getType(x) == "buttonSelect"){
        for (var y in buttons) {
          //show titles for buttons under a button group
          if (tb.getListOptionPosition(x,y)> 0 && typeof buttons[y].title != "undefined") {
            tb.setListOptionToolTip(x, y, buttons[y].title);
          }
        }
      }
    }
  }
}

// Re-Initialize a single toolbar
function miqReinitToolbar(tb_name){
	var tb = miq_toolbars[tb_name]['obj'];
//	tb.clearAll();
// Workaround to replace clearAll method call, it's is not available in 2.0 version of dhtmlx
	tb.forEachItem(function(id) {
		tb.removeItem(id);
	});
	var tb_hash = miq_toolbars[tb_name];
	tb.loadXMLString(tb_hash['xml']);
	miqHideToolbarButtons();
}

// Function to run transactions when toolbar two state button is clicked
function miqToolbarOnStateChange(id, state){
	miqToolbarOnClick(id);
}

// Function to run transactions when toolbar button is clicked
function miqToolbarOnClick(id){
	var tb_url;
	var tb_hash;
	var button;
//	tb_hash = miq_toolbars.get(this.base.id);	// Use this line for toolbar v2.1
		tb_hash = miq_toolbars[this.base.parentNode.id];	// Use this line for toolbar v3.0

	eval("button = tb_hash['buttons']." + id);
	if (typeof button != "undefined") {
		if (typeof button.confirm != "undefined" && typeof button.popup == "undefined") {
			if (!confirm(button.confirm)) return;
		} else if (typeof button.confirm != "undefined" && typeof button.popup != "undefined") {
			// to open console in a new window
			if (confirm(button.confirm)) {
				if (typeof button.popup != "undefined" && button.popup) {					
					if (typeof button.console_url != "undefined"){
						window.open(button.console_url);
			}	}	}
			return;			
		} else if (typeof button.confirm == "undefined" && typeof button.popup != "undefined") {
			// to open readonly report in a new window, doesnt have confirm message
			if (typeof button.popup != "undefined" && button.popup) {
				if (typeof button.console_url != "undefined"){
					window.open(button.console_url);
			}	}
			return;
	}	}
	if (typeof button != "undefined" && typeof button.url != "undefined") {		// See if a url is defined
		if (button.url.indexOf("/") == 0) {			   															// If url starts with / it is non-ajax
			tb_url = "/" + miq_controller + button.url;
			if (typeof miq_record_id != "undefined" && miq_record_id != null) tb_url += "/" + miq_record_id;
			if (typeof button.url_parms != "undefined") tb_url += button.url_parms;
			DoNav(encodeURI(tb_url));
			return;
		} else {																																// An ajax url was defined
			tb_url = "/" + miq_controller + "/" + button.url;
			if (button.url.indexOf("x_history") != 0)	// If not an explorer history button
				if (typeof miq_record_id != "undefined" && miq_record_id != null) tb_url += "/" + miq_record_id;
		}
	}	else {																																	// No url specified, run standard button ajax transaction
		if (typeof button.explorer != "undefined" && button.explorer)						// Use x_button method for explorer ajax
			tb_url = "/" + miq_controller + "/x_button";
		else
			tb_url = "/" + miq_controller + "/button";
		if (typeof miq_record_id != "undefined" && miq_record_id != null) tb_url += "/" + miq_record_id;
		tb_url += "?pressed=";
		if (typeof button.pressed == "undefined")
			tb_url += id.split("__").pop();
		else
			tb_url += button.pressed;
	}

  collect_log_buttons = ['support_vmdb_choice__collect_logs',
                         'support_vmdb_choice__collect_current_logs',
                         'support_vmdb_choice__zone_collect_logs',
                         'support_vmdb_choice__zone_collect_current_logs'
  ]
  if (collect_log_buttons.indexOf(button.name) >= 0 && button.prompt) {
    tb_url = miqSupportCasePrompt(tb_url);
    if (!tb_url) return false;
  }

	// put url_parms into params var, if defined
	var params;
	if (typeof button.url_parms != "undefined") {
		if (button.url_parms.match("_div$")) {
      if (miqDomElementExists('miq_grid_checks')) {
      params = "miq_grid_checks=" + $('#miq_grid_checks').val();
      } else {
        params = miqSerializeForm(button.url_parms);
      }
		} else {
			params = button.url_parms.split("?")[1];
	}	}

	// TODO:
	// Checking for perf_reload button to not turn off spinning Q (will be done after charts are drawn).
	// Need to design this feature into the toolbar button support at a later time.
  if ((button.name == "perf_reload") ||
		  (button.name == "vm_perf_reload") ||
      (button.name.match("_console$"))) {
		if (typeof params == "undefined") {
      miqJqueryRequest(tb_url, {beforeSend: true,});
		} else {
      miqJqueryRequest(tb_url, {beforeSend: true, data: params});
	}	}
	else {
		if (typeof params == "undefined") {
      miqJqueryRequest(tb_url, {beforeSend: true, complete: true});
		} else {
      miqJqueryRequest(tb_url, {beforeSend: true, complete: true, data: params});
	}	}
	return false;
}

function miqSupportCasePrompt(tb_url) {
  var support_case = prompt('Enter Support Case:', '');
  if (support_case == null) return false;
  else if (support_case.trim() == '') {
    alert('Support Case must be provided to collect logs');
    return false;
  }
  else {
    tb_url = tb_url + '&support_case=' + encodeURIComponent(support_case);
    return tb_url;
  }
}


// Handle chart context menu clicks
function miqWidgetToolbarClick(itemId, itemValue) {
	var i = 1;
	if (itemId == "reset") {
		if (confirm("Are you sure you want to reset this Dashboard's Widgets to the defaults?")) {
			miqAjax("/dashboard/reset_widgets");
		}
	} else if (itemId == "add_widget") {
		return;
	} else {
		miqAjax("/dashboard/widget_add?widget=" + itemId);
	}
}
