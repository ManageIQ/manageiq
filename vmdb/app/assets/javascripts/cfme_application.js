// MIQ specific JS functions

// Things to be done on page loads
function miqOnLoad() {

  miq_widget_dd_url = "dashboard/widget_dd_done";     // controller to be used in url in miqDropComplete method
  if (miqDomElementExists('col1')) miqInitDashboardCols();  // Initialize the dashboard column sortables
  if (miqDomElementExists('widget_select_div')) miqInitWidgetPulldown();  // Initialize the dashboard widget pulldown

  if (typeof init_dhtmlx_layout != "undefined") {
    miqInitDhtmlxLayout();  // Need this since IE will not run JS correctly until after page is loaded
  }

  $j(document).mousemove(function(e){
    miqGetMouseXY(e.pageX, e.pageY)
  });
  if (miqDomElementExists('compare_grid')) {  // Need to do this here for IE, rather then right after the grid is initialized
    compare_grid.enableAutoHeight(true);
    compare_grid.enableAutoWidth(true);
  }
  miqBuildCalendar();
  miqLoadCharts();
  if (typeof miqLoadTL == "function"){
    miqLoadTL();
    if (miq_timeline_filter){
      performFiltering(tl, [0,1]);
    }
  }

  if (typeof miqInitGrids == "function") miqInitGrids();            // Initialize dhtmlxgrid control

  if (typeof miqInitToolbars == "function") miqInitToolbars();      // Init the toolbars

  if (typeof miqEditor != "undefined") miqEditor.refresh();         // Refresh the myCodeMirror editor

  if (typeof miq_tree_focus == "string") eval(miq_tree_focus);      // Focus on certain tree node, if set

  if (miqDomElementExists('clear_search'))                             // Position clear search link in right cell header
    $j('.dhtmlxInfoBarLabel:visible').append($j('#clear_search')[0])  // Find the right cell header div

  if (typeof miq_after_onload == "string") eval(miq_after_onload);  // Run MIQ after onload code if present

  // Focus on search box, if it's there and allows focus
  if ($j('#search_text').length) {
    try{
      $j('#search_text').focus();
    }
    catch(er){}
  }
}

function miqPrepRightCellForm(tree) {
  if ($j('#adv_searchbox_div')) $j('#adv_searchbox_div').hide();
  dhxLayoutB.cells("a").collapse();
  $j('#' + tree).dynatree('disable');
  miqDimDiv(tree + '_div', true);
}

// Things to be done on page resize
function miqOnResize() {
//  if ($('miq_timeline')) miqResizeTL();
  miqGetBrowserSize();
}

// Initialize the widget pulldown on the dashboard
function miqInitWidgetPulldown() {
  var miqMenu = new dhtmlXToolbarObject("widget_select_div", "miq_blue");
  miqMenu.setIconsPath("/images/icons/24/");
  miqMenu.attachEvent("onClick", miqWidgetToolbarClick);
  miqMenu.loadXMLString(miqMenuXML); // miqMenuXML var is loaded in dashboard/_dropdownbar.rhtml
  miqSetToolbarButtonIds(miqMenu);
}

function miqCalendarDateConversion(server_offset){
  x=new Date(tN().getUTCFullYear(),tN().getUTCMonth(),tN().getUTCDate(),tN().getUTCHours(),tN().getUTCMinutes(),tN().getUTCSeconds());if(server_offset >= 0){x.setTime(x.getTime()+(Number(server_offset))*1000)}else{x.setTime(x.getTime()-(Number(server_offset.slice(1,server_offset.length)))*1000)};
  return x;
}

// Track the mouse coordinates for popup menus
var miqMouseX, miqMouseY;
function miqGetMouseXY(positionX, positionY){
  miqMouseX = positionX,
  miqMouseY = positionY;
}

// Prefill text entry field when blank
function miqLoginPrefill() {
  if (miqDomElementExists('user_name')) miqPrefill($j('#user_name')[0]);
  if (miqDomElementExists('user_password')) miqPrefill($j('#user_password')[0]);
  if (miqDomElementExists('user_new_password')) miqPrefill($j('#user_new_password')[0]);
  if (miqDomElementExists('user_verify_password')) miqPrefill($j('#user_verify_password')[0]);
  if (miqDomElementExists('user_name')) self.setTimeout('miqLoginPrefill()',200); // Retry in .2 seconds, if user name field is present
}

// Prefill expression value text entry fields when blank
function miqExpressionPrefill(count) {
  if (miqDomElementExists('chosen_value') && $j('#chosen_value')[0].type.startsWith('text')) {
    miqPrefill($j('#chosen_value')[0], '/images/layout/expression/' + miq_val1_type + '.png');
    $j('#chosen_value').prop('title', miq_val1_title);
    $j('#chosen_value').prop('alt', miq_val1_title);
  }
  if (miqDomElementExists('chosen_cvalue') && $j('#chosen_cvalue')[0].type.startsWith('text')) {
    miqPrefill($j('#chosen_cvalue')[0], '/images/layout/expression/' + miq_val2_type + '.png');
    $j('#chosen_cvalue').prop('title', miq_val2_title);
    $j('#chosen_cvalue').prop('alt', miq_val2_title);
  }
  if (miqDomElementExists('chosen_regkey') && $j('#chosen_regkey')[0].type.startsWith('text')) {
    miqPrefill($j('#chosen_regkey')[0], '/images/layout/expression/string.png');
    var title = "Registry Key";
    $j('#chosen_regkey').prop('title', title);
    $j('#chosen_regkey').prop('alt', title);
  }
  if (miqDomElementExists('chosen_regval') && $j('#chosen_regval')[0].type.startsWith('text')) {
    miqPrefill($j('#chosen_regval')[0], '/images/layout/expression/string.png');
    var title = "Registry Key Value";
    $j('#chosen_regval').prop('title', title);
    $j('#chosen_regval').prop('alt', title);
  }
  if (miqDomElementExists('miq_date_1_0') && $j('#miq_date_1_0')[0].type.startsWith('text')) {
    miqPrefill($j('#miq_date_1_0')[0], '/images/layout/expression/' + miq_val1_type + '.png');
    $j('#miq_date_1_0').prop('title', miq_val1_title);
    $j('#miq_date_1_0').prop('alt', miq_val1_title);
  }
  if (miqDomElementExists('miq_date_1_1') && $j('#miq_date_1_1')[0].type.startsWith('text')) {
    miqPrefill($j('#miq_date_1_1')[0], '/images/layout/expression/' + miq_val1_type + '.png');
    $j('#miq_date_1_1').prop('title', miq_val1_title);
    $j('#miq_date_1_1').prop('alt', miq_val1_title);
  }
  if (miqDomElementExists('miq_date_2_0') && $j('#miq_date_2_0')[0].type.startsWith('text')) {
    miqPrefill($j('#miq_date_2_0')[0], '/images/layout/expression/' + miq_val2_type + '.png');
    $j('#miq_date_2_0').prop('title', miq_val2_title);
    $j('#miq_date_2_0').prop('alt', miq_val2_title);
  }
  if (miqDomElementExists('miq_date_2_1') && $j('#miq_date_2_1')[0].type.startsWith('text')) {
    miqPrefill($j('#miq_date_2_1')[0], '/images/layout/expression/' + miq_val2_type + '.png');
    $j('#miq_date_2_1').prop('title', miq_val2_title);
    $j('#miq_date_2_1').prop('alt', miq_val2_title);
  }
  if (typeof count == 'undefined') {
    miq_exp_prefill_count = 0;
    eval("self.setTimeout('miqExpressionPrefill("+ miq_exp_prefill_count + ")',200);");
  }
  else if (count == miq_exp_prefill_count) {
    miq_exp_prefill_count += 1;
    if (miq_exp_prefill_count > 100) miq_exp_prefill_count = 0;
    eval("self.setTimeout('miqExpressionPrefill("+ miq_exp_prefill_count + ")',200);");
  }
}

// Prefill report editor style value text entry fields when blank
// (written more generic for reuse, just have to build the miq_value_styles hash)
function miqValueStylePrefill(count) {
  var found = false;
  for (field in miq_value_styles) {
    if (miqDomElementExists(field)) {
      miqPrefill($j('#' + field)[0], '/images/layout/expression/' + miq_value_styles[field] + '.png');
      found = true;
    }
  }
  if (found) {
    if (typeof count == 'undefined') {
      miq_vs_prefill_count = 0;
      eval("self.setTimeout('miqValueStylePrefill("+ miq_vs_prefill_count + ")',200);");
    }
    else if (count == miq_vs_prefill_count) {
      miq_vs_prefill_count += 1;
      if (miq_vs_prefill_count > 100) miq_vs_prefill_count = 0;
      eval("self.setTimeout('miqValueStylePrefill("+ miq_vs_prefill_count + ")',200);");
    }
  }
}

// Prefill text entry field when blank
function miqPrefill(element, image, blank_image) {
  if(element.value=='')
    element.style.background="url(" + image + ") no-repeat transparent"
  else
    if (typeof blank_image == 'undefined')
      element.style.background="transparent"
    else
      element.style.background="url(" + blank_image + ") no-repeat transparent"
}

// Get user's time zone offset
function miqGetTZO() {
  var uDate = new Date();
  if(uDate)
    if (miqDomElementExists('user_TZO')) $j('#user_TZO').val(uDate.getTimezoneOffset()/60);
}

// Get user's browswer info
function miqGetBrowserInfo() {
  var bd;
  bd = miqBrowserDetect();
  if (miqDomElementExists('browser_name')) $j('#browser_name').val(bd.browser);
  if (miqDomElementExists('browser_version')) $j('#browser_version').val(bd.version);
  if (miqDomElementExists('browser_os')) $j('#browser_os').val(bd.OS);
}

// Turn highlight on or off
function miqHighlight(elem, status) {
  if (status) {
    if($j(elem).length) $j(elem).addClass('active');
  } else {
    if($j(elem).length) $j(elem).removeClass('active');
  }
}

// Turn on activity indicator
function miqSparkle(status) {
  if (status) {
    if ($j.active > 0) {  // Make sure an ajax request is active before sparkling
      miqSparkleOn();
    }
  } else {
    if ($j.active < 2) {  // Make sure all but 1 ajax request is done
      miqSparkleOff();
    }
  }
}

function miqSparkleOn() {
  if($j('#notification').length) $j('#notification').show();
  miqSpinner(true);
}

function miqSparkleOff() {
  miqSpinner(false);
  if($j('#notification').length) $j('#notification').hide();
  if($j('#rep_notification').length) $j('#rep_notification').hide();
}

// dim/un-dim a div: pass divname and status (true to dim, false to un-dim)
function miqDimDiv(divname, status) {
  if ($j(divname).length) {
    if (status)
      $j(divname).addClass('dimmed');
    else
      $j(divname).removeClass('dimmed');
} }

// Check for changes and prompt
function miqCheckForChanges() {
  if(cfmeAngularApplication.$scope) {
    if (cfmeAngularApplication.$scope.form.$dirty)
      return confirm("Abandon changes?");
    } else {
        if (((miqDomElementExists('buttons_on') && $j('#buttons_on').is(":visible")) ||
          typeof miq_changes != "undefined") &&
          !miqDomElementExists('ignore_form_changes'))
            return confirm("Abandon changes?");
    }
  return true;
}

// go to the specified URL when a download all log files button is pressed
function miqDownloadLogFiles(theUrl,count) {
  for(i=0;i<count;i++){
    new_url = theUrl + "?i=" + i
    winName = "log" + i
    window.open(new_url,winName,'top=0,left=0,width=1, height=1,directories=no,location=no,menubar=no,resizable=no,scrollbars=no,status=no,toolbar=no')
  }
}

// Prompt for new tags
function miqNewTagPrompt() {
  text = prompt('Enter new tags, separated by blanks','');
    if (text == null) return false;
  else {
    $j('#new_tag').val(text);
    return true;
} }

// Hide/show form buttons
function miqButtons(h_or_s, prefix) {
  $j('#flash_msg_div').hide();

  var on  = h_or_s == 'show' ? 'on'  : 'off';
  var off = h_or_s == 'show' ? 'off' : 'on';

  prefix = (typeof(prefix) === 'undefined' || prefix === '') ? '' : (prefix + '_');

  $j('#' + prefix + 'buttons_' + on).show();
  $j('#' + prefix + 'buttons_' + off).hide();
}

// Hide/show form buttons
function miqValidateButtons(h_or_s, prefix) {
  var prefix = (prefix == null) ? "" : prefix;
  on_id = "#" + prefix + 'validate_buttons_on';
  off_id = "#" + prefix + 'validate_buttons_off';
  if ($j('flash_msg_div')) $j('flash_msg_div').hide();
    if (h_or_s == "show") {
      if($j(on_id)) $j(on_id).show();
      if($j(off_id)) $j(off_id).hide();
    } else {
      if($j(off_id)) $j(off_id).show();
      if($j(on_id)) $j(on_id).hide();
}   }

// Convert Button image to hyperlink
function toggleConvertButtonToLink(button, url, toggle) {
  if (toggle == true) {
    if(button.hasClass('dimmed')) {
      button.removeClass('dimmed')
    }
    if(button[0].parentNode.outerHTML.indexOf('<a href') == -1) {
      button[0].outerHTML = "<a href=" + url + " title='" + button[0].getAttribute('alt') + "'>" + button[0].outerHTML + "</a>";
    }
  }
  else {
    if(!button.hasClass('dimmed')) {
      button.addClass('dimmed')
    }
    if(button[0].parentNode.outerHTML.indexOf('<a href') > -1) {
      button[0].parentNode.outerHTML = button[0].outerHTML;
    }
  }
}

// update all checkboxes on a form when the masterToggle checkbox is changed
// parms: button_div=<id of div with buttons to update>, override=<forced state>
function miqUpdateAllCheckboxes(button_div,override) {
  miqSparkle(true);
  if (miqDomElementExists('masterToggle')) {
    var state = $j('#masterToggle').prop('checked');
    if ( override != null ) state = override;
    if (typeof gtl_list_grid == "undefined" && ($j("input[id^='listcheckbox']").length > 0)) {             // No dhtmlx grid on the screen
      $j("input[id^='listcheckbox']").each(function() {
        this.checked=state;
      })
      miqUpdateButtons(this.first(), button_div);
    } else if (typeof gtl_list_grid == "undefined" && $j("input[id^='storage_cb']").length > 0) {         // to handle check/uncheck all for C&U collection
      $j("input[id^='storage_cb']").each(function() {
          this.checked=state;
        })
      miqJqueryRequest("/configuration/form_field_changed?storage_cb_all=" + state);
    return true;
    } else {                                                // Set checkboxes in dhtmlx grid
      gtl_list_grid.forEachRow(function(id) {
        gtl_list_grid.cells(id, 0).setValue(state ? 1:0);
      })
      crows = gtl_list_grid.getCheckedRows(0);
      $j('#miq_grid_checks').val(crows);
      count = crows == "" ? 0:crows.split(",").length;
      miqSetButtons(count, button_div);
    }
  }
  miqSparkle(false);
}

// Update buttons based on number of checkboxes that are checked
// parms: obj=<checkbox element>, button_div=<id of div with buttons to update>
function miqUpdateButtons(obj, button_div) {
  var count = 0;
  if (typeof obj.id != "undefined" ) {
    $j("input[id^='" + obj.id + "']").each(function() {
      if (this.checked && ! this.disabled) count++;
        if (count > 1) return false;
    })
  } else if (typeof obj == 'number') {      // Check for number object, as passed from snapshot tree
    count = 1;
  }
  miqSetButtons(count, button_div);
}

// Set the buttons in a div based on the count of checked items passed in
function miqSetButtons(count, button_div) {
  var tb;
  var buttons;
  if (button_div.endsWith("_tb")) {
    if (typeof miq_toolbars[button_div] != "undefined"){
      tb = miq_toolbars[button_div]["obj"];
      buttons = miq_toolbars[button_div]["buttons"];
      for (button in buttons) {
        onwhen = eval("buttons." + button + ".onwhen");
        if (typeof onwhen != "undefined") {
          if (count == 0) {
            if (button.indexOf("__") >= 0) tb.disableListOption(button.split("__")[0], button);  else tb.disableItem(button);
          } else if (count == 1) {
            if (onwhen == "1" || onwhen == "1+") {
              if (button.indexOf("__") >= 0) tb.enableListOption(button.split("__")[0], button); else tb.enableItem(button);
            } else if (onwhen == "2+") {
              if (button.indexOf("__") >= 0) tb.disableListOption(button.split("__")[0], button);  else tb.disableItem(button);
            }
          } else {
            if (onwhen == "1+" || onwhen == "2+") {
              if (button.indexOf("__") >= 0) tb.enableListOption(button.split("__")[0], button); else tb.enableItem(button);
            } else if (onwhen = "1") {
              if (button.indexOf("__") >= 0) tb.disableListOption(button.split("__")[0], button);  else tb.disableItem(button);
            }
          }
        }
      }
    }
  } else if (button_div.endsWith("_buttons")) { // Handle newer divs with button elements
    if (count == 0) {
      $j("#" + button_div + " button[id$=on_1]").each(function() {this.disabled = true});
    } else if (count == 1) {
      $j("#" + button_div + " button[id$=on_1]").each(function() {this.disabled = false});
    } else {
      $j("#" + button_div + " button[id$=on_1]").each(function() {this.disabled = false});
    }
  } else {  // Handle older li based buttons
    if (count == 0) {
      $j('#' + button_div + ' li[id~=on_1]').each(function() {$j(this).hide()})
      $j('#' + button_div + ' li[id~=on_2]').each(function() {$j(this).hide()})
      $j('#' + button_div + ' li[id~=on_only_1]').each(function() {$j(this).hide()})
      $j('#' + button_div + ' li[id~=off_0]').each(function() {$j(this).show()})
      $j('#' + button_div + ' li[id~=off_1]').each(function() {$j(this).show()})
      $j('#' + button_div + ' li[id~=off_not_1]').each(function() {$j(this).show()})
    } else if (count == 1) {
      $j('#' + button_div + ' li[id~=off_0]').each(function() {$j(this).hide()})
      $j('#' + button_div + ' li[id~=on_2]').each(function() {$j(this).hide()})
      $j('#' + button_div + ' li[id~=off_not_1]').each(function() {$j(this).hide()})
      $j('#' + button_div + ' li[id~=off_1]').each(function() {$j(this).show()})
      $j('#' + button_div + ' li[id~=on_1]').each(function() {$j(this).show()})
      $j('#' + button_div + ' li[id~=on_only_1]').each(function() {$j(this).show()})
    } else {
      $j('#' + button_div + ' li[id~=off_0]').each(function() {$j(this).hide()})
      $j('#' + button_div + ' li[id~=off_1]').each(function() {$j(this).hide()})
      $j('#' + button_div + ' li[id~=on_only_1]').each(function() {$j(this).hide()})
      $j('#' + button_div + ' li[id~=on_1]').each(function() {$j(this).show()})
      $j('#' + button_div + ' li[id~=on_2]').each(function() {$j(this).show()})
      $j('#' + button_div + ' li[id~=off_not_1]').each(function() {$j(this).show()})
}}}

// ChangeColor and DoNav are for making a full table row clickable and
// highlight-able.  Found here:
//   http://imar.spaanjaars.com/312/how-do-i-make-a-full-table-row-clickable
// TODO: Convert to jQuery UJS, possibly like so:
//   http://www.electrictoolbox.com/jquey-make-entire-table-row-clickable/

// Change table cell colors as mouse moves
function ChangeColor(tablecell, highLight) {
  if (highLight) tablecell.style.backgroundColor = '#f1f1f1';
  else tablecell.style.backgroundColor = '';
}

// go to the specified URL when a table cell is clicked
function DoNav(theUrl) {
  document.location.href = theUrl;
}

// Routines to get the size of the window - original reference: http://www.communitymx.com/blog/index.cfm?newsid=622
var size_timer = false;
// Get the size and pass to the server
function miqGetBrowserSize() {
  if (size_timer) return;
  size_timer = true;
  self.setTimeout('miqResetSizeTimer()',1000);
}
function miqResetSizeTimer() {
  size_timer = false;
  var theArray = miqGetSize();
  var url = "/dashboard/window_sizes";
  var args = new Array();
  args.push("width");
  args.push(theArray[0]);
  args.push("height");
  args.push(theArray[1]);

  var offset = 427;

  if (typeof xml != "undefined") {  // If grid xml is available for reload
    // Adjust certain elements, if present
    if ($j('#list_grid').length) {
      h = theArray[1] - offset;
      if (h < 200) h = 200;
      $j('#list_grid').css({height: h + 'px' });
      gtl_list_grid.clearAll();
      gtl_list_grid.parse(xml);
    } else if ($j('#logview').length) {
      h = theArray[1] - offset;
      if (h < 200) h = 200;
      $j('#logview').css({height: h + 'px' });
    }
  }

  miqPassFields(url, args); // Send the new values to the server
}
function miqGetSize() {
  var myWidth = 0, myHeight = 0;
  if(typeof(window.innerWidth) == 'number') {
    //Non-IE
    myWidth = window.innerWidth;
    myHeight = window.innerHeight;
  }else if(document.documentElement &&
    (document.documentElement.clientWidth || document.documentElement.clientHeight)) {
    //IE 6+ in 'standards compliant mode'
    myWidth = document.documentElement.clientWidth;
    myHeight = document.documentElement.clientHeight;
  } else if(document.body && (document.body.clientWidth || document.body.clientHeight)) {
    //IE 4 compatible
    myWidth = document.body.clientWidth;
    myHeight = document.body.clientHeight;
  }
  return [myWidth, myHeight];
}
// Pass fields to server given a URL and fields in name/value pairs
function miqPassFields(url,args) {
  url += '?';
  for(var i=0; i<args.length; i=i+2) {
    url += args[i] + '=' + args[i+1] + '&';
  }
  miqJqueryRequest(url);
}

// Create a new div to put the notification area at the bottom of the screen whenever the page loads
function wrapFish() {
  var catfish = document.getElementById('notification');
  var subelements = [];
  for (var i = 0; i < document.body.childNodes.length; i++) {
    subelements[i] = document.body.childNodes[i];
  }
  var zip = document.createElement('div');    // Create the outer-most div (zip)
  zip.id = 'zip';                      // call it zip
  for (var i = 0; i < subelements.length; i++) {
    zip.appendChild(subelements[i]);
  }
  document.body.appendChild(zip); // add the major div
  document.body.appendChild(catfish); // add the catfish after the zip
}

// Commented out addLoadEvent and code to run it, now running wrapFish(); in globalheader since
//   it was stepping on inline JS to set focus and log postitioning.
//// Add a function to the onload event
//function addLoadEvent(func) {
//  var oldonload = window.onload;
//  if (typeof window.onload != 'function') {
//    window.onload = func;
//  } else {
//    window.onload = function() {
//      if (oldonload) {
//        oldonload();
//      }
//      func();
//    }
//  }
//}
//
//// Setup the notification area at the bottom of the screen when the page loads
//addLoadEvent(function() {
//  wrapFish();
//});

// Load XML/SWF charts data (non-IE)
// This method is called by the XML/SWF charts when a chart is loaded into the DOM
var miq_chart_data;
function Loaded_Chart(chart_id){
  if ((miq_browser != 'Explorer') && (typeof(miq_chart_data) !== 'undefined'))
    doLoadChart(chart_id, document.getElementsByName(chart_id)[0]);
}

function doLoadChart(chart_id, chart_object) {
  var id_splitted = chart_id.split('_');
  set  = id_splitted[1];
  idx  = id_splitted[2];
  comp = id_splitted[3];
  if (typeof(comp) === 'undefined')
    chart_object.Update_XML(miq_chart_data[set][idx].xml, false);
  else
    chart_object.Update_XML(miq_chart_data[set][idx].xml2, false);
}

// Load XML/SWF charts data (IE)
function miqLoadCharts() {
  if (typeof miq_chart_data != 'undefined' && miq_browser == 'Explorer') {
    for (var set in miq_chart_data) {
      var mcd = miq_chart_data[set];
      for (var i = 0; i < mcd.length; i = i + 1) {
        miqLoadChart("miq_" + set + "_" + i);
        if (typeof mcd[i].xml2 != "undefined")
          miqLoadChart("miq_" + set + "_" + i + "_2");
      }
    }
  }
}

function miqLoadChart(chart_id) {
  var chart_object = 'undefined';
  if (typeof document.getElementById(chart_id) != 'undefined' &&
      typeof document.getElementById(chart_id).Update_XML != 'undefined') { //Verify with console.log after sleep
    chart_object = document.getElementById(chart_id);
  } else if (typeof document.getElementsByName(chart_id)[0] != 'undefined' &&
             typeof document.getElementsByName(chart_id)[0].Update_XML != 'undefined') {
    chart_object = document.getElementsByName(chart_id)[0];
  }
  chart_object == 'undefined' ? self.setTimeout(function() { miqLoadChart(chart_id); }, 100) : doLoadChart(chart_id, chart_object);
}

function miqChartLinkData(col, row, value, category, series, id, message) {
// Create the context menu
  if (typeof miqMenu != "undefined") miqMenu.hideContextMenu();
  if (category.startsWith("<Other(")) return; // No menus for <Other> category
  //Added delay before showing menus to get it work in version 3.5
  self.setTimeout("miqBuildChartMenu('" + col + "', '" + row + "', '" + value + "', '" + category + "', '" + series + "', '" + id + "', '" + message + "')",250);
}

function miqBuildChartMenu(col, row, value, category, series, id, message) {
  set = id.split('_')[1];   // Get the chart set
  idx = id.split('_')[2];   // Get the chart index
  var chart_data = miq_chart_data[set];
  if (chart_data[idx].menu != null && chart_data[idx].menu.length > 0) {
    var rowcolidx = "_" + row + "-" + col+ "-" + idx;
    miqMenu=new dhtmlXMenuObject(null, "dhx_web");
    miqMenu.setImagePath("/assets/dhtmlx_gpl_36/imgs/");
    miqMenu.renderAsContextMenu();
    //Removed with version 3.5
    //miqMenu.setOpenMode("win");
    miqMenu.setWebModeTimeout(1000);
    miqMenu.attachEvent("onClick",miqChartMenuClick);
    miqMenu.setAutoHideMode(true);
    for (var i = 0; i < chart_data[idx].menu.length; i++) {
      var menu_id = chart_data[idx].menu[i].split(":")[0] + rowcolidx;
      var pid = menu_id.split("-")[0];
      if (miqMenu.getParentId(pid) == null) miqMenu.addNewChild(miqMenu.topId, 99, pid, pid, false);
      var menu_title = chart_data[idx].menu[i].split(":")[1];
      menu_title = menu_title.replace("<series>", series);
      menu_title = menu_title.replace("<category>", category);
      miqMenu.addNewChild(pid, 99, menu_id, menu_title, false);
    }
    miqMenu.showContextMenu(miqMouseX - 10, miqMouseY - 10);
  }
}

// Handle chart context menu clicks
function miqChartMenuClick(itemId, itemValue) {
  if ($j('#menu_div').length) $j('#menu_div').hide();
//  if (itemId != "cancel") miqAjax("?menu_click=" + itemId);
  if (itemId != "cancel") miqAsyncAjax("?menu_click=" + itemId);
}

var miqAjaxTimers = 0;

// Handle an ajax form button press (i.e. Submit) by starting the spinning Q, then waiting for .7 seconds for observers to finish
function miqAjaxButton(url, serialize_fields){
  if (typeof serialize_fields == "unknown") serialize_fields = false;
  if($j('#notification').length) $j('#notification').show();
  miqAjaxTimers++;
  self.setTimeout("miqAjaxButtonSend('" + url + "', " + serialize_fields + ")",700);
}

// Send ajax url after any outstanding ajax requests, wait longer if needed
function miqAjaxButtonSend(url, serialize_fields){
  if ($j.active > 0) {
    miqAjaxTimers++;
    self.setTimeout("miqAjaxButtonSend('" + url + "')",700);
  }
  else miqAjax(url, serialize_fields);
  miqAjaxTimers--;
}

// Function to generate an Ajax request
function miqAjax(url, serialize_fields) {
  if (serialize_fields) {
    miqJqueryRequest(url, {beforeSend: true, complete: true, data: miqSerializeForm('form_div')});
  } else {
    miqJqueryRequest(url, {beforeSend: true, complete: true});
  }
}

// Function to generate an Ajax request for EVM async processing
function miqAsyncAjax(url) {
  miqJqueryRequest(url, {beforeSend: true});
}

// Function to generate an Ajax request, but only once for a drawn screen
var miqOneTrans = 0;
function miqSendOneTrans(url) {
  if (typeof miqIEButtonPressed != "undefined") {
    // page replace after clicking save/reset was making observe_field on text_area in IE send up a trascation to form_field_changed method
    delete miqIEButtonPressed;
    return;
  }
  if (miqOneTrans == 1) return;
  miqOneTrans = 1;
  miqJqueryRequest(url);
}

// Anytime Anywhere Web Page Clock Generator
// Clock Script Generated at
// http://www.rainbow.arch.scriptmania.com/tools/clock
function tS(){x=new Date(tN().getUTCFullYear(),tN().getUTCMonth(),tN().getUTCDate(),tN().getUTCHours(),tN().getUTCMinutes(),tN().getUTCSeconds()); if(zone_offset >= 0){x.setTime(x.getTime()+(Number(zone_offset))*1000)}else{x.setTime(x.getTime()-(Number(zone_offset.slice(1,zone_offset.length)))*1000)}; return x; }
function tN(){ return new Date(); }
function lZ(x){ return (x>9)?x:'0'+x; }
function y2(x){ x=(x<500)?x+1900:x; return String(x).substring(2,4) }
var zone_offset;
var zone_abbr;
function dT(offset,abbr){if(offset != undefined){zone_offset = offset};if(abbr != undefined){zone_abbr = abbr;};if(fr==0){ fr=1; document.write('<span id="tP">'+eval(oT)+'</span>'); } document.getElementById('tP').innerHTML=eval(oT); setTimeout('dT(zone_offset,zone_abbr)',1000); }
var dN=new Array('Sun','Mon','Tue','Wed','Thu','Fri','Sat'),mN=new Array('1','2','3','4','5','6','7','8','9','10','11','12'),fr=0,oT="mN[tS().getMonth()]+'/'+tS().getDate()+'/'+y2(tS().getYear())+' '+lZ(tS().getHours())+':'+lZ(tS().getMinutes())+' '+ zone_abbr";

// this deletes the remembered treestate when called
function miqClearTreeState(prefix) {
  if (undefined === prefix) prefix = 'treeOpenStatex';
  var to_remove = [];
  for (var i = 0; i < localStorage.length; i++) {
    if (localStorage.key(i).match('^' + prefix))
      to_remove.push(localStorage.key(i));
  }

  for(i=0; i < to_remove.length; i++) {
    localStorage.removeItem(to_remove[i]);
  }
}

// Check max length on a text area and set remaining chars
function miqCheckMaxLength(obj){
  var ml=obj.getAttribute ? parseInt(obj.getAttribute("maxlength")) : "";
  var counter=obj.getAttribute ? obj.getAttribute("counter") : "";
  if (obj.getAttribute && obj.value.length>ml) obj.value=obj.value.substring(0,ml);
  if (counter != "")
    if (miq_browser != 'Explorer') $j('#' + counter)[0].textContent = obj.value.length;
    else $j('#' + counter).innerText = obj.value.length;
}

function miqSetInputClass(fld,cname,typ){
  if (typ == "remove"){
    $j(fld).removeClass(cname)
  } else {
    $j(fld).addClass(cname)
  }
}

// Check for enter key pressed
function miqEnterPressed(e){
  var keycode;
  if (window.event)
    keycode = window.event.keyCode;
  else if (e)
    keycode = e.which;
  else
    return false;
return (keycode == 13);
}

// Send login authentication via ajax
function miqAjaxAuth(button){
  if (button == null) {
    miqEnableLoginFields(false);
    miqJqueryRequest('/dashboard/authenticate', {beforeSend: true, data: miqSerializeForm('login_div')});
  } else if (button == 'more' || button == 'back') {
    miqJqueryRequest('/dashboard/authenticate?' + miqSerializeForm('login_div') + '&button=' + button);
  } else {
    miqEnableLoginFields(false);
    miqAsyncAjax('/dashboard/authenticate?' + miqSerializeForm('login_div') + '&button=' + button);
  }
}

function miqEnableLoginFields(enabled){
  $j('#user_name').prop('readonly', !enabled);
  $j('#user_password').prop('readonly', !enabled);
  if (miqDomElementExists('user_new_password')) $j('#user_new_password').prop('readonly', !enabled);
  if (miqDomElementExists('user_verify_password')) $j('#user_verify_password').prop('readonly', !enabled);
}

// Attach text area with id = id + "_lines" to work with the text area id passed in
function miqAttachTextAreaWithLines(id){
  var el = document.getElementById(id + "_lines");
  var ta = document.getElementById(id);
  var string = '';
  for(var no=1;no<300;no++){
    if(string.length>0)string += '\n';
    string += no;
  }
  el.style.height = (ta.offsetHeight-3) + "px";
  el.style.overflow = 'hidden';
  el.style.textAlign = 'right';
  el.innerHTML = string; //Firefox renders \n linebreak
  el.innerText = string; //IE6 renders \n line break
  el.scrollTop = ta.scrollTop;
  ta.focus();

  ta.onkeydown    = function() { el.scrollTop   = ta.scrollTop; }
  ta.onmousedown  = function() { el.scrollTop   = ta.scrollTop; }
  ta.onmouseup    = function() { el.scrollTop   = ta.scrollTop; }
  ta.onmousemove  = function() { el.scrollTop   = ta.scrollTop; }
}

///////////// place all jQuery functions below this line /////////////////////

// Initialize dashboard column jQuery sortables
function miqInitDashboardCols() {
  if ($j('#col1')) {
    $j('#col1').sortable({connectWith:'#col2, #col3', handle:"h2"});
    $j('#col1').bind('sortupdate', miqDropComplete);
  }
  if ($j('#col2')) {
    $j('#col2').sortable({connectWith:'#col1, #col3', handle:"h2"});
    $j('#col2').bind('sortupdate', miqDropComplete);
  }
  if ($j('#col3')) {
    $j('#col3').sortable({connectWith:'#col1, #col2', handle:"h2"});
    $j('#col3').bind('sortupdate', miqDropComplete);
  }
}

// Send the updated sortable order after jQuery drag/drop
function miqDropComplete(event, ui) {
  var el = $j(this);
  var url = "/" + miq_widget_dd_url + "?" + el.sortable('serialize', {key:el.attr('id') + "[]"}).toString();
  //Adding id of record being edited to be used by load_edit call
  if(typeof miq_record_id != "undefined") url += "&id=" + miq_record_id
  miqJqueryRequest(url);
}

// Attach a calendar control to all text boxes that start with miq_date_
function miqBuildCalendar(){
  var all = $j('input[id^=miq_date_]');   // Get all of the input boxes with ids starting with "miq_date_"
  all.each(function() {                   // Attach dhtmlxcalendars to each one
    var el = $j(this);
    var cal = new dhtmlxCalendarObject(el.attr('id'));
    cal.setDateFormat("%m/%d/%Y");
    if (el.val() == "" && typeof miq_cal_dateTo != "undefined"){
      cal.setDate(miq_cal_dateTo);
    } else {
      cal.setDate(this.value);
    }
    cal.setSkin("dhx_skyblue");
    cal.hideTime();
    cal.setPosition('right');
    //start week from sunday, default is (1) monday
    cal.setWeekStartDay(7);
    if ((typeof miq_cal_dateFrom != "undefined") && (typeof miq_cal_dateTo != "undefined")){
      cal.setSensitiveRange(miq_cal_dateFrom, miq_cal_dateTo);
    } else if ((typeof miq_cal_dateFrom != "undefined") && (typeof miq_cal_dateTo == "undefined")){
      cal.setSensitiveRange(miq_cal_dateFrom);
    }
    if (typeof miq_cal_skipDays != "undefined" && miq_cal_skipDays != null && miq_cal_skipDays != '')
      cal.setInsensitiveRange(miq_cal_skipDays);

    // Create an observer for the date field if the html5 attr is specified
    if (this.getAttribute('data-miq_observe_date')) {
      el.change(function() { miqSendDateRequest(el); })
      cal.attachEvent("onClick", function(){ miqSendDateRequest(el); });
    }

  });
}

function miqSendDateRequest(el){
  var parms = $j.parseJSON(el.attr('data-miq_observe_date'));
  var url = parms.url;
  var urlstring = url + '?' + el.prop('id') + '=' + el.val(); //  tack on the id and value to the URL
  if (el.attr('data-miq_sparkle_on')) {
    miqJqueryRequest(urlstring, {beforeSend: true});
  } else {
    miqJqueryRequest(urlstring);
  }
}

// Build an explorer view using a YUI layout and a jQuery accordion
function miqBuildExplorerView(options){
  // Set the default values in the object, then extend it to include the values that we passed to it.
  var settings = $j.extend({
  accord_url: null,
  width: 1000,
  divider: 4,
  left: 0,
  resize: false,
  layout_div: 'layout_div',
  left_div: 'accordion_div',
  active_accord: null,
  center_div: null,
  header: null
  },options||{}); //If no options, pass an empty object

  $j(document).ready(function() { // On doc ready, build the layout and accordion

    // Build object for center layout unit settings
    var centerHash = {
      position: 'center'
    };
    // Passed in if a div will be used, else we're nesting mainLayout, so leave null
    if (settings.header != null) {
      body: settings.center_div
    };
    // Only add header if option specified (because passing header:null still shows a thin header)
    if (settings.header != null) {
      centerHash["header"] = settings.header
    };

    // Build the layout
    if (settings.left == 0) settings.left = settings.width/settings.divider;  // If no saved width, calculate
    var expLayout = new YAHOO.widget.Layout(settings.layout_div, {
      units: [
        {
          position: 'left',
          width: settings.left,
          body: settings.left_div,
          collapse: false,
          gutter: '0 5 0 0',
          resize: settings.resize,
          minWidth: settings.width/8,
          maxWidth: settings.width/2
        },
        centerHash
      ]
    });
    expLayout.on('render',function() {
      if (miqDomElementExists('main_div')) {
        miqBuildMainLayout(this, settings.header);
      }
    });

    expLayout.render();

    // Show the layout divs right after layout rendering
    $j("#" + settings.center_div).show();
    $j("#" + settings.left_div).show();

    // Set up event to capture center layout resize
    var clu = expLayout.getUnitByPosition('center');
    clu.addListener('leftChange', miqExplorerResize);

    // Build the accordion
    $j("#" + settings.left_div).accordion({
      change: function(event,ui){miqAccordionChange(event, ui, settings.accord_url)},
      fillSpace: true,
      active: "#" + settings.active_accord,
      icons: false,
      animated: false
//      event: 'mouseover'
//      clearStyle: true
//      autoHeight: false
    });
//    $j("#" + settings.left_div).accordion("option", "autoHeight", false);
//    $j("#" + settings.left_div).accordion("option", "fillSpace", true);
//    $j("#" + settings.left_div).accordion("option", "clearStyle", true);
  });

}

// Build the nested GTL layout inside the explorer layout
function miqBuildMainLayout(parentLayout, header){
  var el = parentLayout.getUnitByPosition('center').get('wrap');
//  parentLayout.getUnitByPosition('center').set('header', "Test");
  if (miqDomElementExists('paging_div')) var paging_height = 35; else var paging_height = 0;
  var mainLayout = new YAHOO.widget.Layout(el, {
//  var mainLayout = new YAHOO.widget.Layout('center_div', {
    parent: parentLayout,
    id: 'main_layout',
    units: [
      {
        position: 'top',
        body: 'taskbar_div',
        height: 40,
        collapse: false
      },
      {
        position: 'bottom',
        body: 'paging_div',
        height: paging_height,
        gutter: "0px 0px 5px 0px",
        collapse: false
      },
      {
        position: 'center',
        header: header,
        body: 'main_div',
        scroll: true,
        gutter: "5px 0px 5px 0px",
        collapse: false
      }
    ]
  });

  mainLayout.render();

  $j("#main_div").show();
  $j("#taskbar_div").show();
  $j("#paging_div").show();
}

function miqExplorerResize(e){
//  alert("Event: " + e.type + " old: " + e.oldValue + " new: " + e.newValue);
  var url = "/dashboard/window_sizes";
  var args = new Array();
  args.push("exp_controller");
  args.push(miq_controller);
  args.push("exp_left");
  args.push(e.newValue);
  miqPassFields(url, args); // Send the new values to the server
}
function miqAccordionChange(event, ui, url){
//  alert ("Accordion Changed from " + ui.oldHeader.text() + " to " + ui.newHeader.text())
//  alert ("Accordion changed to " + ui.newHeader.context.id)
  return miqAjaxRequest(ui.newHeader.context.id, url);
}

function miqSetLayoutHeader(unitId, text){
  return YAHOO.widget.LayoutUnit.getLayoutUnitById(unitId).set('header', text);
}

//common function to pass ajax request to server
function miqAjaxRequest(itemId,path){
  if (miqCheckForChanges() == false) {
    return false;
  } else {
    miqJqueryRequest(path + '?id=' + itemId, {beforeSend: true, complete: true});
    return true;
  }
}

// Handle an element onclick to open href in a new window with optional confirmation
function miqClickAndPop(el) {
  conmsg = el.getAttribute("data-miq_confirm");
  if (conmsg == null || confirm(conmsg)) window.open(el.href);
  return false;
}

//method takes 4 parameters tabs div id, active tab label, url to go to when tab is changed, and whether to check for abandon changes or not
function miq_jquery_tabs_init(options){

  //initializing tabs
  $j("#" + options['tabs_div']).tabs();
  //setting active tab after tabs are loaded using name of tab
  if (options['active_tab']){
    var index = $j('#' + options['tabs_div'] + ' a[href=\"#' + options['active_tab'] + '\" ]').parent().index();
    $j('#' + options['tabs_div']).tabs('select', index);
  }

  if (options['url']){
    // passing in ui element of tabs, url to use for ajax transaction and whether to check for changes,
    // used bind to prevent from extra tab change transaction when all tabs are loaded from controller and active tab is changed
    $j( "#" + options['tabs_div'] ).bind( "tabsselect", function(event, ui) {
      // added a workaround to make sure that bind url for main outer tabs is not being used as a url for sub tabs
      // do not bind if subtabs dont need to send up a transaction
      var bind_url = ui.panel.parentNode.getAttribute('data-miq_url');
      if (bind_url == "_none_"){
        return;
      } else if (bind_url != null) {
        return miq_jquery_tab_select(ui, bind_url, false);
      } else {
        return miq_jquery_tab_select(ui, options['url'], options['tab_changes'] ? options['tab_changes'] : false);
      }
    });
  } else if (options['cm_tab']) {
    //forcing to refresh the codemirror text box when tab is changed, so it displays properly
    $j( "#" + options['tabs_div'] ).bind( "tabsshow", function(event, ui) {
      if (options['cm_tab'] == ui.panel.id) {
        miqEditor.refresh();
      }
    });
  } else if (options['show_buttons_tab']) {
    // show/hide toolbar div based on selected tab
    $j( "#" + options['tabs_div'] ).bind( "tabsselect", function(event, ui) {
      if (options['show_buttons_tab'] == ui.panel.id) {
        $j("#center_buttons_div").show();
      } else {
        $j("#center_buttons_div").hide();
      }
    });
  }

  // Hide the first tab, if only one
  if ($j("#" + options['tabs_div'] + " ul:first li").length == 1) {
    $j("#" + options['tabs_div'] + " ul:first li").hide();
  }

  $j("#" + options['tabs_div']).show();
}

// OnSelect handler for change tab transaction for jquery ui tabs
// getting in ui element of tabs, url to use for ajax transaction and whether to check for changes, prov screens don't need to check for changes on tab change
function miq_jquery_tab_select(ui,url,checkChanges) {
  if (checkChanges && miqCheckForChanges() == false) {
    return false;
  } else {
    miqJqueryRequest(url + '?tab_id=' + ui.panel.id, {beforeSend: true});
    return true;
  }
}

function miq_jquery_disable_inactive_tabs(tabs_div){
  //getting length of tabs on screen
  tab_len = $j('#' + tabs_div).tabs('length');
  //getting index of currently active tabs
  curTab = $j('#' + tabs_div).tabs().tabs('option', 'selected').valueOf();
  //building array of tab indexes to be disabled, excluding active tab index
  var arr=new Array
  for(var i=1,j=0;i<=tab_len;i++){
    if(i != curTab+1){
      arr[j++] = i-1;
    }
  }
  $j('#' + tabs_div).tabs('option','disabled', arr);
}

function miq_jquery_show_hide_tab(tab_li_id,s_or_h){
  //there is no default method to show/hide jquery tabs, need to have unique li id to do a show/hide on those
  if (s_or_h == "hide"){
    $j("#" + tab_li_id).css("display","none")
  } else {
    $j("#" + tab_li_id).css("display","list-item")
  }
}

function miq_jquery_disable_all_tabs(tabs_div){
  //getting length of tabs on screen
  tab_len = $j('#' + tabs_div).tabs('length');
  //building array of tab indexes to be disabled, excluding active tab index
  var arr=new Array
  for(var i=1;i<=tab_len;i++){
    arr[i] = i;
  }
  $j('#' + tabs_div).tabs('option','disabled', arr);
}

// Send explorer search by name via ajax
function miqSearchByName(button){
  if (button == null)
    miqJqueryRequest('x_search_by_name', {beforeSend: true, data: miqSerializeForm('input')});
}

// Send search by filter via ajax
function miqSearchByFilter(button){
  if (button == null)
    miqJqueryRequest('list_view_filter', {beforeSend: true, data: miqSerializeForm('input')});
}

// Send transaction to server so automate tree selection box can be made active and rest of the screen can be blocked
function miqShowAE_Tree(typ){
  miqJqueryRequest('ae_tree_select_toggle?typ=' + typ);
  return true;
}

// Use the jQuery.form plugin for ajax file upload
function miqInitJqueryForm(){
  $j('#uploadForm input').change(function(){
    $j(this).parent().ajaxSubmit({
      beforeSubmit: function(a,f,o) {
        o.dataType = 'script';
        miqSparkleOn();
      }
    });
  });
}

// Launch the VNC Console using the miqvncplugin
function miqLaunchMiqVncConsole(pwd, hostAddress, hostPort, proxyAddress, proxyPort) {
  if (typeof miqvncplugin != "undefined" && typeof miqvncplugin.launchVnc != "undefined") {
    miqSparkleOn();
    miqvncplugin.launchVnc(pwd, hostAddress, hostPort, proxyAddress, proxyPort);
    miqSparkleOff();
  } else alert("The MIQ VNC plugin is not installed");
}

// Toggle the user options div in the page header
function miqToggleUserOptions(e, id){
  if (id == 'user_options_div')
    $j('#user_options_div').toggle();

  if ( e.stopPropagation )  // Don't propagate the mouse click to the dom event catcher
    e.stopPropagation();
  e.cancelBubble = true;
  return false;
}

// Check for enter/escape on quick search box
function miqQsEnterEscape(e){
  var keycode;
  if (window.event)
    keycode = window.event.keyCode;
  else if (e)
    keycode = e.keyCode;
  else
    return false;
  if (keycode == 13)
    if ($j('#apply_button').is(':visible'))
      miqAjaxButton('quick_search?button=apply');
  if (keycode == 27) miqAjaxButton('quick_search?button=cancel');
}

// Start/stop the JS spinner
function miqSpinner(status){
  if (status) {
    if (typeof spinner == "undefined") {
      var opts = {
        lines: 15, // The number of lines to draw
        length: 18, // The length of each line
        width: 4, // The line thickness
        radius: 25, // The radius of the inner circle
        corners: 1, // Corner roundness (0..1)
        rotate: 0, // The rotation offset
        color: '#fff', // #rgb or #rrggbb
        speed: 1, // Rounds per second
        trail: 60, // Afterglow percentage
        shadow: false, // Whether to render a shadow
        hwaccel: false, // Whether to use hardware acceleration
        className: 'spinner', // The CSS class to assign to the spinner
        zIndex: 2e9, // The z-index (defaults to 2000000000)
        top: 'auto', // Top position relative to parent in px
        left: 'auto' // Left position relative to parent in px
      };
      spinner = new Spinner(opts).spin($j('#spinner_div')[0]);
    } else {
      spinner.spin($j('#spinner_div')[0]);
    }
  } else {
    if (typeof spinner != "undefined") spinner.stop();
  }
}

/*
 * Registers a callback which copies the csrf token into the
 * X-CSRF-Token header with each ajax request.  Necessary to
 * work with rails applications which have fixed
 * CVE-2011-0447
 */
$j( document ).ajaxSend(function( event, request, settings ) {
  var csrf_meta_tag = $j('#meta[name=csrf-token]')[0];

  if (csrf_meta_tag) {
    var header = 'X-CSRF-Token',
      token = csrf_meta_tag.readAttribute('content');
  }
});

function miqJqueryRequest(url, options) {
  options = options || {};
  ajax_options = {};

  if (options['dataType'] === undefined) {
    ajax_options['accepts']  = { script: '*/*;q=0.5, ' + $j.ajaxSettings.accepts.script };
    ajax_options['dataType'] = 'script';
  }
  if (options['data'])       ajax_options['data']       = options['data'];
  if (options['beforeSend']) ajax_options['beforeSend'] = function(request) { miqSparkle(true); };
  if (options['complete'])   ajax_options['complete']   = function(request) { miqSparkle(false); };

  new $j.ajax(options['no_encoding'] ? url : encodeURI(url), ajax_options);
}

function miqDomElementExists(element){
  return $j('#' + element).length
}

function miqSerializeForm(element){
  return $j('#' + element).find('input,select,textarea').serialize();
}


