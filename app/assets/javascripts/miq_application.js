// MIQ specific JS functions

// Things to be done on page loads
function miqOnLoad() {
  // controller to be used in url in miqDropComplete method
  ManageIQ.widget.dashboardUrl = "dashboard/widget_dd_done";

  // Initialize the dashboard column sortables
  if ($('#col1').length) {
    miqInitDashboardCols();
  }
  // Initialize the dashboard widget pulldown
  if ($('#widget_select_div').length) {
    miqInitWidgetPulldown();
  }
  // Need this since IE will not run JS correctly until after page is loaded
  if (typeof miqInitDhtmlxLayout == "function") {
    miqInitDhtmlxLayout();
  }

  $(document).mousemove(function (e) {
    miqGetMouseXY(e.pageX, e.pageY);
  });

  // Need to do this here for IE, rather then right after the grid is initialized
  if ($('#compare_grid').length) {
    $('#compare_grid')[0].enableAutoHeight(true);
    $('#compare_grid')[0].enableAutoWidth(true);
  }

  miqBuildCalendar();
  miqLoadCharts();

  if (typeof miqLoadTL == "function") {
    miqLoadTL();
    if (ManageIQ.timelineFilter) {
      performFiltering(tl, [ 0, 1 ]);
    }
  }

  // Initialize dhtmlxgrid control
  if (typeof miqInitGrids == "function") {
    miqInitGrids();
  }
  // Init the toolbars
  if (typeof miqInitToolbars == "function") {
    miqInitToolbars();
  }
  // Refresh the myCodeMirror editor
  if (ManageIQ.editor !== null) {
    ManageIQ.editor.refresh();
  }
  // Position clear search link in right cell header
  if ($('#clear_search').length) {
    // Find the right cell header div
    $('.dhtmlxInfoBarLabel:visible').append($('#clear_search'));
  }
  // Run MIQ after onload code if present
  if (typeof miq_after_onload == "string") {
    eval(miq_after_onload);
  }
  // Focus on search box, if it's there and allows focus
  if ($('#search_text').length) {
    try {
      $('#search_text').focus();
    } catch (er) {}
  }
}

function miqPrepRightCellForm(tree) {
  if ($('#adv_searchbox_div').length) {
    $('#adv_searchbox_div').hide();
  }
  dhxLayoutB.cells("a").collapse();
  $('#' + tree).dynatree('disable');
  miqDimDiv(tree + '_div', true);
}

// Things to be done on page resize
function miqOnResize() {
  if (typeof dhxLayout != "undefined") {
    dhxLayout.setSizes();
  }
  miqBrowserSizeTimeout();
}

// Initialize the widget pulldown on the dashboard
function miqInitWidgetPulldown() {
  var miqMenu = new dhtmlXToolbarObject("widget_select_div", "miq_blue");
  miqMenu.setIconsPath("/images/icons/24/");
  miqMenu.attachEvent("onClick", miqWidgetToolbarClick);
  // ManageIQ.widget.menuXml var is loaded in dashboard/_dropdownbar.rhtml
  miqMenu.loadXMLString(ManageIQ.widget.menuXml);
  miqSetToolbarButtonIds(miqMenu);
}

function miqCalendarDateConversion(server_offset) {
  return moment().utcOffset(Number(server_offset) / 60);
}

// Track the mouse coordinates for popup menus
function miqGetMouseXY(positionX, positionY) {
  ManageIQ.mouse.x = positionX;
  ManageIQ.mouse.y = positionY;
}

// Prefill text entry field when blank
function miqLoginPrefill() {
  miqPrefill($('#user_name'));
  miqPrefill($('#user_password'));
  miqPrefill($('#user_new_password'));
  miqPrefill($('#user_verify_password'));
  if ($('#user_name').length) {
    // Retry in .2 seconds, if user name field is present
    setTimeout(miqLoginPrefill, 200);
  }
}

// Prefill expression value text entry fields when blank
function miqExpressionPrefill(expEditor, noPrefillCount) {
  var title;

  if ($('#chosen_value[type=text]').length) {
    miqPrefill($('#chosen_value'), '/images/layout/expression/' + expEditor.first.type + '.png');
    $('#chosen_value').prop('title', expEditor.first.title);
    $('#chosen_value').prop('alt', expEditor.first.title);
  }
  if ($('#chosen_cvalue[type=text]').length) {
    miqPrefill($('#chosen_cvalue'), '/images/layout/expression/' + expEditor.second.type + '.png');
    $('#chosen_cvalue').prop('title', expEditor.second.title);
    $('#chosen_cvalue').prop('alt', expEditor.second.title);
  }
  if ($('#chosen_regkey[type=text]').length) {
    miqPrefill($('#chosen_regkey'), '/images/layout/expression/string.png');
    title = "Registry Key";
    $('#chosen_regkey').prop('title', title);
    $('#chosen_regkey').prop('alt', title);
  }
  if ($('#chosen_regval[type=text]').length) {
    miqPrefill($('#chosen_regval'), '/images/layout/expression/string.png');
    title = "Registry Key Value";
    $('#chosen_regval').prop('title', title);
    $('#chosen_regval').prop('alt', title);
  }
  if ($('#miq_date_1_0[type=text]').length) {
    miqPrefill($('#miq_date_1_0'), '/images/layout/expression/' + expEditor.first.type + '.png');
    $('#miq_date_1_0').prop('title', expEditor.first.title);
    $('#miq_date_1_0').prop('alt', expEditor.first.title);
  }
  if ($('#miq_date_1_1[type=text]').length) {
    miqPrefill($('#miq_date_1_1'), '/images/layout/expression/' + expEditor.first.type + '.png');
    $('#miq_date_1_1').prop('title', expEditor.first.title);
    $('#miq_date_1_1').prop('alt', expEditor.first.title);
  }
  if ($('#miq_date_2_0[type=text]').length) {
    miqPrefill($('#miq_date_2_0'), '/images/layout/expression/' + expEditor.second.type + '.png');
    $('#miq_date_2_0').prop('title', expEditor.second.title);
    $('#miq_date_2_0').prop('alt', expEditor.second.title);
  }
  if ($('#miq_date_2_1[type=text]').length) {
    miqPrefill($('#miq_date_2_1'), '/images/layout/expression/' + expEditor.second.type + '.png');
    $('#miq_date_2_1').prop('title', expEditor.second.title);
    $('#miq_date_2_1').prop('alt', expEditor.second.title);
  }
  if (noPrefillCount) {
    expEditor.prefillCount = 0;
    setTimeout(function () {
      miqExpressionPrefill(expEditor, false);
    }, 200);
  } else {
    if (++expEditor.prefillCount > 100) {
      expEditor.prefillCount = 0;
    }
    setTimeout(function () {
      miqExpressionPrefill(expEditor, false);
    }, 200);
  }
}

// Prefill report editor style value text entry fields when blank
// (written more generic for reuse, just have to build
// the ManageIQ.reportEditor.valueStyles hash)
function miqValueStylePrefill(count) {
  var found = false;

  for (var field in ManageIQ.reportEditor.valueStyles) {
    if ($(field).length) {
      miqPrefill($(field), '/images/layout/expression/' + ManageIQ.reportEditor.valueStyles[field] + '.png');
      found = true;
    }
  }
  if (found) {
    if (typeof count == 'undefined') {
      ManageIQ.reportEditor.prefillCount = 0;
      setTimeout(function () {
        miqValueStylePrefill(ManageIQ.reportEditor.prefillCount);
      }, 200);
    } else if (count == ManageIQ.reportEditor.prefillCount) {
      if (++ManageIQ.reportEditor.prefillCount > 100) {
        ManageIQ.reportEditor.prefillCount = 0;
      }
      setTimeout(function () {
        miqValueStylePrefill(ManageIQ.reportEditor.prefillCount);
      }, 200);
    }
  }
}

// Prefill text entry field when blank
function miqPrefill(element, image, blank_image) {
  if (element.length) {
    if ($(element).val()) {
      if (blank_image === '') {
        $(element).css('background-color', 'transparent');
      } else {
        $(element).css('background', 'url(' + blank_image + ') no-repeat transparent');
      }
    } else {
      $(element).css('background', 'url(' + image + ') no-repeat transparent');
    }
  }
}

// Get user's time zone offset
function miqGetTZO() {
  if ($('#user_TZO').length) {
    $('#user_TZO').val(moment().utcOffset() / 60);
  }
}

// Get user's browswer info
function miqGetBrowserInfo() {
  var bd = miqBrowserDetect();

  if ($('#browser_name').length) {
    $('#browser_name').val(bd.browser);
  }
  if ($('#browser_version').length) {
    $('#browser_version').val(bd.version);
  }
  if ($('#browser_os').length) {
    $('#browser_os').val(bd.OS);
  }
}

// Turn highlight on or off
function miqHighlight(elem, status) {
  if (status) {
    if ($(elem).length) {
      $(elem).addClass('active');
    }
  } else {
    if ($(elem).length) {
      $(elem).removeClass('active');
    }
  }
}

// Turn on activity indicator
function miqSparkle(status) {
  if (status) {
    // Make sure an ajax request is active before sparkling
    if ($.active) {
      miqSparkleOn();
    }
  } else {
    // Make sure all but 1 ajax request is done
    if ($.active < 2) {
      miqSparkleOff();
    }
  }
}

function miqSparkleOn() {
  if ($('#advsearchModal').length &&
      ($('#advsearchModal').hasClass('modal fade in'))) {
    if ($('#searching_spinner_center').length) {
      miqSearchSpinner(true);
    }
    miqSpinner(false);
    if ($('#notification').length) {
      $('#notification').hide();
    }
  } else {
    if ($('#notification').length) {
      $('#notification').show();
    }
    miqSpinner(true);
  }
}

function miqSparkleOff() {
  miqSpinner(false);
  if ($('#searching_spinner_center').length) {
    miqSearchSpinner(false);
  }
  if ($('#notification').length) {
    $('#notification').hide();
  }
  if ($('#rep_notification').length) {
    $('#rep_notification').hide();
  }
}

// dim/un-dim a div: pass divname and status (true to dim, false to un-dim)
function miqDimDiv(divname, status) {
  if ($(divname).length) {
    if (status) {
      $(divname).addClass('dimmed');
    } else {
      $(divname).removeClass('dimmed');
    }
  }
}

// Check for changes and prompt
function miqCheckForChanges() {
  if (ManageIQ.angularApplication.$scope) {
    if (ManageIQ.angularApplication.$scope.form.$dirty) {
      var answer = confirm("Abandon changes?");
      if (answer) {
        ManageIQ.angularApplication.$scope.form.$setPristine(true);
      }
      return answer;
    }
  } else {
    if ((($('#buttons_on').length &&
          $('#buttons_on').is(":visible")) ||
         ManageIQ.changes !== null) &&
        !$('#ignore_form_changes').length) {
      return confirm("Abandon changes?");
    }
  }
  // use default browser reaction for onclick
  return true;
}

// go to the specified URL when a download all log files button is pressed
function miqDownloadLogFiles(theUrl, count) {
  for (var i = 0; i < count; i++) {
    var new_url = theUrl + "?i=" + i;
    var winName = "log" + i;
    window.open(new_url, winName,
      'top=0,' +
      'left=0,' +
      'directories=0,' +
      'location=0,' +
      'menubar=0,' +
      'resizable=0,' +
      'scrollbars=0,' +
      'status=0,' +
      'toolbar=0'
    );
  }
}

// Prompt for new tags
function miqNewTagPrompt() {
  var text = prompt('Enter new tags, separated by blanks', '');
  if (text !== null) {
    $('#new_tag').val(text);
    return true;
  } else {
    return false;
  }
}

// Hide/show form buttons
function miqButtons(h_or_s, prefix) {
  $('#flash_msg_div').hide();

  var on = h_or_s == 'show' ? 'on' : 'off';
  var off = h_or_s == 'show' ? 'off' : 'on';

  prefix = (typeof prefix === 'undefined' || prefix === '') ? '' : (prefix + '_');

  $('#' + prefix + 'buttons_' + on).show();
  $('#' + prefix + 'buttons_' + off).hide();
}

// Hide/show form validate buttons
function miqValidateButtons(h_or_s, prefix) {
  prefix = (prefix == null) ? "" : prefix;
  var on_id = '#' + prefix + 'validate_buttons_on';
  var off_id = '#' + prefix + 'validate_buttons_off';

  if ($('#flash_msg_div').length) {
    $('flash_msg_div').hide();
  }

  if (h_or_s == "show") {
    if ($(on_id).length) {
      $(on_id).show();
    }
    if ($(off_id).length) {
      $(off_id).hide();
    }
  } else {
    if ($(off_id).length) {
      $(off_id).show();
    }
    if ($(on_id).length) {
      $(on_id).hide();
    }
  }
}

// Convert Button image to hyperlink
function toggleConvertButtonToLink(button, url, toggle) {
  if (toggle) {
    button.removeClass('dimmed');
    if (!button.parent().is('a[href]')) {
      button
        .wrap($('<a/>')
          .attr('href', url)
          .attr('title', button.attr('alt')));
    }
  } else {
    button.addClass('dimmed');
    if (button.parent().is('a[href]')) {
      button.unwrap();
    }
  }
}

// update all checkboxes on a form when the masterToggle checkbox is changed
// parms: button_div=<id of div with buttons to update>, override=<forced state>
function miqUpdateAllCheckboxes(button_div, override) {
  miqSparkle(true);
  if ($('#masterToggle').length) {
    var state = $('#masterToggle').prop('checked');
    if (override != null) {
      state = override;
    }
    if (typeof ManageIQ.grids.grids.gtl_list_grid == 'undefined' &&
        ($("input[id^='listcheckbox']").length)) {
      // No dhtmlx grid on the screen
      $("input[id^='listcheckbox']").prop('checked', state);
      miqUpdateButtons(cbs[0], button_div);
    } else if (typeof ManageIQ.grids.grids.gtl_list_grid == 'undefined' &&
               $("input[id^='storage_cb']").length) {
      // to handle check/uncheck all for C&U collection
      $("input[id^='storage_cb']").prop('checked', state);
      miqJqueryRequest(miqPassFields(
        "/configuration/form_field_changed",
        {storage_cb_all: state}
      ));
      return true;
    } else {
      // Set checkboxes in dhtmlx grid
      ManageIQ.grids.grids.gtl_list_grid.obj.forEachRow(function (id) {
        ManageIQ.grids.grids.gtl_list_grid.obj.cells(id, 0).setValue(state ? 1 : 0);
      });
      var crows = ManageIQ.grids.grids.gtl_list_grid.obj.getCheckedRows(0);
      $('#miq_grid_checks').val(crows);
      var count = !crows ? 0 : crows.split(",").length;
      miqSetButtons(count, button_div);
    }
  }
  miqSparkle(false);
}

// Update buttons based on number of checkboxes that are checked
// parms: obj=<checkbox element>, button_div=<id of div with buttons to update>
function miqUpdateButtons(obj, button_div) {
  var count = 0;

  if (typeof obj.id != "undefined") {
    $("input[id^='" + obj.id + "']").each(function () {
      if (this.checked && !this.disabled) {
        count++;
      }
      if (count > 1) {
        return false;
      }
    });
  // Check for number object, as passed from snapshot tree
  } else if (typeof obj == 'number') {
    count = 1;
  }
  miqSetButtons(count, button_div);
}

// Set the buttons in a div based on the count of checked items passed in
function miqSetButtons(count, button_div) {
  var tb;
  var buttons;

  if (button_div.match("_tb$")) {
    if (typeof ManageIQ.toolbars[button_div] != "undefined") {
      tb = ManageIQ.toolbars[button_div].obj;
      buttons = ManageIQ.toolbars[button_div].buttons;
      for (var button in buttons) {
        var onwhen = buttons[button].onwhen;
        if (typeof onwhen != "undefined") {
          if (count === 0) {
            if (button.indexOf("__") >= 0) {
              tb.disableListOption(button.split("__")[0], button);
            } else {
              tb.disableItem(button);
            }
          } else if (count == 1) {
            if (onwhen == "1" || onwhen == "1+") {
              if (button.indexOf("__") >= 0) {
                tb.enableListOption(button.split("__")[0], button);
              } else {
                tb.enableItem(button);
              }
            } else if (onwhen == "2+") {
              if (button.indexOf("__") >= 0) {
                tb.disableListOption(button.split("__")[0], button);
              } else {
                tb.disableItem(button);
              }
            }
          } else {
            if (onwhen == "1+" || onwhen == "2+") {
              if (button.indexOf("__") >= 0) {
                tb.enableListOption(button.split("__")[0], button);
              } else {
                tb.enableItem(button);
              }
            } else if (onwhen == "1") {
              if (button.indexOf("__") >= 0) {
                tb.disableListOption(button.split("__")[0], button);
              } else {
                tb.disableItem(button);
              }
            }
          }
        }
      }
    }
  } else if (button_div.match("_buttons$")) {
    // Handle newer divs with button elements
    if (count === 0) {
      $("#" + button_div + " button[id$=on_1]").prop('disabled', true);
    } else if (count == 1) {
      $("#" + button_div + " button[id$=on_1]").prop('disabled', false);
    } else {
      $("#" + button_div + " button[id$=on_1]").prop('disabled', false);
    }
  } else {
    // Handle older li based buttons
    if (count === 0) {
      $('#' + button_div + ' li[id~=on_1]').hide();
      $('#' + button_div + ' li[id~=on_2]').hide();
      $('#' + button_div + ' li[id~=on_only_1]').hide();
      $('#' + button_div + ' li[id~=off_0]').show();
      $('#' + button_div + ' li[id~=off_1]').show();
      $('#' + button_div + ' li[id~=off_not_1]').show();
    } else if (count === 1) {
      $('#' + button_div + ' li[id~=off_0]').hide();
      $('#' + button_div + ' li[id~=on_2]').hide();
      $('#' + button_div + ' li[id~=off_not_1]').hide();
      $('#' + button_div + ' li[id~=off_1]').show();
      $('#' + button_div + ' li[id~=on_1]').show();
      $('#' + button_div + ' li[id~=on_only_1]').show();
    } else {
      $('#' + button_div + ' li[id~=off_0]').hide();
      $('#' + button_div + ' li[id~=off_1]').hide();
      $('#' + button_div + ' li[id~=on_only_1]').hide();
      $('#' + button_div + ' li[id~=on_1]').show();
      $('#' + button_div + ' li[id~=on_2]').show();
      $('#' + button_div + ' li[id~=off_not_1]').show();
    }
  }
}

// ChangeColor and DoNav are for making a full table row clickable and
// highlight-able.  Found here:
//   http://imar.spaanjaars.com/312/how-do-i-make-a-full-table-row-clickable
// TODO: Convert to jQuery UJS, possibly like so:
//   http://www.electrictoolbox.com/jquey-make-entire-table-row-clickable/

// Change table cell colors as mouse moves
function ChangeColor(tablecell, highLight) {
  if (highLight) {
    tablecell.style.backgroundColor = '#fff';
  } else {
    tablecell.style.backgroundColor = '';
  }
}

// go to the specified URL when a table cell is clicked
function DoNav(theUrl) {
  document.location.href = theUrl;
}

// Routines to get the size of the window
// original reference: http://www.communitymx.com/blog/index.cfm?newsid=622
ManageIQ.sizeTimer = false;

function miqBrowserSizeTimeout() {
  if (ManageIQ.sizeTimer) {
    return;
  }
  ManageIQ.sizeTimer = true;
  setTimeout(miqResetSizeTimer, 1000);
}

function miqResetSizeTimer() {
  ManageIQ.sizeTimer = false;
  var sizes = miqGetSize();
  var offset = 427;
  var h;
  var url = "/dashboard/window_sizes";
  var args = {width: sizes[0], height: sizes[1]};

  if (ManageIQ.grids.xml !== null) {
    // If grid xml is available for reload
    if ($('#list_grid').length) {
      // Adjust certain elements, if present
      h = sizes[1] - offset;
      if (h < 200) {
        h = 200;
      }
      $('#list_grid').css({height: h + 'px'});
      ManageIQ.grids.grids.gtl_list_grid.obj.clearAll();
      ManageIQ.grids.grids.gtl_list_grid.obj.parse(xml);
    } else if ($('#logview').length) {
        h = sizes[1] - offset;
      if (h < 200) {
        h = 200;
      }
      $('#logview').css({height: h + 'px'});
    }
  }

  // Send the new values to the server
  miqJqueryRequest(miqPassFields(url, args));
}

// Get the size and pass to the server
function miqGetSize() {
  var myWidth = 0;
  var myHeight = 0;

  if (typeof window.innerWidth == 'number') {
    // Non-IE
    myWidth = window.innerWidth;
    myHeight = window.innerHeight;
  } else if (document.documentElement &&
             (document.documentElement.clientWidth ||
              document.documentElement.clientHeight)) {
    // IE 6+ in 'standards compliant mode'
    myWidth = document.documentElement.clientWidth;
    myHeight = document.documentElement.clientHeight;
  } else if (document.body &&
             (document.body.clientWidth ||
              document.body.clientHeight)) {
    // IE 4 compatible
    myWidth = document.body.clientWidth;
    myHeight = document.body.clientHeight;
  }
  return [ myWidth, myHeight ];
}

// Pass fields to server given a URL and fields in name/value pairs
function miqPassFields(url, args) {
  return url + '?' + $.param(args);
}

// Create a new div to put the notification area at the bottom of the screen whenever the page loads
function wrapFish() {
  var catfish = document.getElementById('notification');
  var subelements = [];
  var i;

  for (i = 0; i < document.body.childNodes.length; i++) {
    subelements[i] = document.body.childNodes[i];
  }

  // Create the outer-most div (zip)
  var zip = document.createElement('div');
  // call it zip
  zip.id = 'zip';

  for (i = 0; i < subelements.length; i++) {
    zip.appendChild(subelements[i]);
  }

  // add the major div
  document.body.appendChild(zip);
  // add the catfish after the zip
  document.body.appendChild(catfish);
}

// Load XML/SWF charts data (non-IE)
// This method is called by the XML/SWF charts when a chart is loaded into the DOM

function Loaded_Chart(chart_id) {
  if ((ManageIQ.browser != 'Explorer') &&
      (typeof (ManageIQ.charts.chartData) != 'undefined')) {
    doLoadChart(chart_id, document.getElementsByName(chart_id)[0]);
  }
}

function doLoadChart(chart_id, chart_object) {
  var id_splitted = chart_id.split('_');
  var set = id_splitted[1];
  var idx = id_splitted[2];
  var comp = id_splitted[3];

  if (typeof (comp) === 'undefined') {
    chart_object.Update_XML(ManageIQ.charts.chartData[set][idx].xml, false);
  } else {
    chart_object.Update_XML(ManageIQ.charts.chartData[set][idx].xml2, false);
  }
}

// Load XML/SWF charts data (IE)
function miqLoadCharts() {
  if (typeof ManageIQ.charts.chartData != 'undefined' && ManageIQ.browser == 'Explorer') {
    for (var set in ManageIQ.charts.chartData) {
      var mcd = ManageIQ.charts.chartData[set];
      for (var i = 0; i < mcd.length; i++) {
        miqLoadChart("miq_" + set + "_" + i);
        if (typeof mcd[i].xml2 != "undefined") {
          miqLoadChart("miq_" + set + "_" + i + "_2");
        }
      }
    }
  }
}

function miqLoadChart(chart_id) {
  var chart_object;

  if (document.getElementById(chart_id) != undefined &&
      typeof document.getElementById(chart_id) != 'undefined' &&
      typeof document.getElementById(chart_id).Update_XML != 'undefined') {
    // Verify with console.log after sleep
    chart_object = document.getElementById(chart_id);
  } else if (typeof document.getElementsByName(chart_id)[0] != 'undefined' &&
             typeof document.getElementsByName(chart_id)[0].Update_XML != 'undefined') {
    chart_object = document.getElementsByName(chart_id)[0];
  }
  if (chart_object === undefined) {
    setTimeout(function () {
      miqLoadChart(chart_id);
    }, 100);
  } else {
    doLoadChart(chart_id, chart_object);
  }
}

function miqChartLinkData(col, row, value, category, series, id, message) {
  // Create the context menu
  if (typeof miqMenu != "undefined") {
    miqMenu.hideContextMenu();
  }
  if (category.indexOf("<Other(") === 0) {
    // No menus for <Other> category
    return;
  }
  // Added delay before showing menus to get it work in version 3.5
  setTimeout(function () {
    miqBuildChartMenu(col, row, value, category, series, id, message);
  }, 250);
}

function miqBuildChartMenu(col, row, value, category, series, id, message) {
  var set = id.split('_')[1]; // Get the chart set
  var idx = id.split('_')[2]; // Get the chart index
  var chart_data = ManageIQ.charts.chartData[set];

  if (chart_data[idx].menu != null && chart_data[idx].menu.length) {
    var rowcolidx = "_" + row + "-" + col + "-" + idx;
    var miqMenu = new dhtmlXMenuObject(null, "dhx_web");
    miqMenu.setImagePath("/assets/dhtmlx_gpl_36/imgs/");
    miqMenu.renderAsContextMenu();
    miqMenu.setWebModeTimeout(1000);
    miqMenu.attachEvent("onClick", miqChartMenuClick);
    miqMenu.setAutoHideMode(true);

    for (var i = 0; i < chart_data[idx].menu.length; i++) {
      var menu_id = chart_data[idx].menu[i].split(":")[0] + rowcolidx;
      var pid = menu_id.split("-")[0];

      if (miqMenu.getParentId(pid) == null) {
        miqMenu.addNewChild(miqMenu.topId, 99, pid, pid, false);
      }

      var menu_title = chart_data[idx].menu[i].split(":")[1];
      menu_title = menu_title.replace("<series>", series);
      menu_title = menu_title.replace("<category>", category);
      miqMenu.addNewChild(pid, 99, menu_id, menu_title, false);
    }

    miqMenu.showContextMenu(ManageIQ.mouse.x - 10, ManageIQ.mouse.y - 10);
  }
}

// Handle chart context menu clicks
function miqChartMenuClick(itemId, itemValue) {
  if ($('#menu_div').length) {
    $('#menu_div').hide();
  }
  if (itemId != "cancel") {
    miqAsyncAjax("?menu_click=" + itemId);
  }
}

// Handle an ajax form button press (i.e. Submit) by starting the spinning Q,
// then waiting for .7 seconds for observers to finish
function miqAjaxButton(url, serialize_fields) {
  if (typeof serialize_fields == "undefined") {
    serialize_fields = false;
  }
  if ($('#notification').length) {
    $('#notification').show();
  }

  setTimeout(function () {
    miqAjaxButtonSend(url, serialize_fields);
  }, 700);
}

// Send ajax url after any outstanding ajax requests, wait longer if needed
function miqAjaxButtonSend(url, serialize_fields) {
  if ($.active) {
    setTimeout(function () {
      miqAjaxButtonSend(url);
    }, 700);
  } else {
    miqAjax(url, serialize_fields);
  }
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

ManageIQ.oneTransition.oneTrans = 0;

// Function to generate an Ajax request, but only once for a drawn screen
function miqSendOneTrans(url) {
  if (typeof ManageIQ.oneTransition.IEButtonPressed != "undefined") {
    // page replace after clicking save/reset was making observe_field on
    // text_area in IE send up a trascation to form_field_changed method
    ManageIQ.oneTransition.IEButtonPressed = undefined;
    return;
  }
  if (ManageIQ.oneTransition.oneTrans) {
    return;
  }

  ManageIQ.oneTransition.oneTrans = 1;
  miqJqueryRequest(url);
}

// Function to write date and time to page footer each second
function dateTime(offset, abbr) {
  var date = miqCalendarDateConversion(offset);

  $('#tP').html(date.format("MM/DD/YYYY HH:mm ") + abbr);
  setTimeout(function () {
    dateTime(offset, abbr);
  }, 1000);
}

// this deletes the remembered treestate when called
function miqClearTreeState(prefix) {
  var to_remove = [];
  var i;

  if (prefix === undefined) {
    prefix = 'treeOpenStatex';
  }
  for (i = 0; i < localStorage.length; i++) {
    if (localStorage.key(i).match('^' + prefix)) {
      to_remove.push(localStorage.key(i));
    }
  }

  for (i = 0; i < to_remove.length; i++) {
    localStorage.removeItem(to_remove[i]);
  }
}

// Check max length on a text area and set remaining chars
function miqCheckMaxLength(obj) {
  var ml = obj.getAttribute ? parseInt(obj.getAttribute("maxlength"), 10) : "";
  var counter = obj.getAttribute ? obj.getAttribute("counter") : "";

  if (obj.getAttribute && obj.value.length > ml) {
    obj.value = obj.value.substring(0, ml);
  }
  if (counter) {
    if (ManageIQ.browser != 'Explorer') {
      $('#' + counter)[0].textContent = obj.value.length;
    } else {
      $('#' + counter).innerText = obj.value.length;
    }
  }
}

function miqSetInputClass(fld, cname, typ) {
  if (typ == "remove") {
    $(fld).removeClass(cname);
  } else {
    $(fld).addClass(cname);
  }
}

// Check for enter key pressed
function miqEnterPressed(e) {
  var keycode;

  if (window.event) {
    keycode = window.event.keyCode;
  } else if (e) {
    keycode = e.which;
  } else {
    return false;
  }
  return (keycode == 13);
}

// Send login authentication via ajax
function miqAjaxAuth(button) {
  if (button == null) {
    miqEnableLoginFields(false);
    miqJqueryRequest(
      '/dashboard/authenticate',
      {beforeSend: true, data: miqSerializeForm('login_div')}
    );
  } else if (button == 'more' || button == 'back') {
    miqJqueryRequest(
      '/dashboard/authenticate?' +
      miqSerializeForm('login_div') + '&button=' + button
    );
  } else {
    miqEnableLoginFields(false);
    miqAsyncAjax(
      '/dashboard/authenticate?' +
      miqSerializeForm('login_div') + '&button=' + button
    );
  }
}

function miqEnableLoginFields(enabled) {
  $('#user_name').prop('readonly', !enabled);
  $('#user_password').prop('readonly', !enabled);
  if ($('#user_new_password').length) {
    $('#user_new_password').prop('readonly', !enabled);
  }
  if ($('#user_verify_password').length) {
    $('#user_verify_password').prop('readonly', !enabled);
  }
}

// Attach text area with id = id + "_lines" to work with the text area id passed in
function miqAttachTextAreaWithLines(id) {
  var el = document.getElementById(id + "_lines");
  var ta = document.getElementById(id);
  var string = '';

  for (var no = 1; no < 300; no++) {
    if (string.length) {
      string += '\n';
    }
    string += no;
  }

  el.style.height = (ta.offsetHeight - 3) + "px";
  el.style.overflow = 'hidden';
  el.style.textAlign = 'right';
  el.innerHTML = string; // Firefox renders \n linebreak
  el.innerText = string; // IE6 renders \n line break
  el.scrollTop = ta.scrollTop;

  ta.focus();
  var scrollTop = function () {
    el.scrollTop = ta.scrollTop;
  }
  ta.onkeydown = scrollTop;
  ta.onmousedown = scrollTop;
  ta.onmouseup = scrollTop;
  ta.onmousemove = scrollTop;
}

// Initialize dashboard column jQuery sortables
function miqInitDashboardCols() {
  if ($('#col1').length) {
    $('#col1').sortable({connectWith: '#col2, #col3', handle: "h2"});
    $('#col1').off('sortupdate');
    $('#col1').on('sortupdate', miqDropComplete);
  }
  if ($('#col2').length) {
    $('#col2').sortable({connectWith: '#col1, #col3', handle: "h2"});
    $('#col2').off('sortupdate');
    $('#col2').on('sortupdate', miqDropComplete);
  }
  if ($('#col3').length) {
    $('#col3').sortable({connectWith: '#col1, #col2', handle: "h2"});
    $('#col3').off('sortupdate');
    $('#col3').on('sortupdate', miqDropComplete);
  }
}

// Send the updated sortable order after jQuery drag/drop
function miqDropComplete(event, ui) {
  var el = $(this);
  var url = "/" + ManageIQ.widget.dashboardUrl + "?" + el.sortable(
              'serialize', {key: el.attr('id') + "[]"}
            ).toString();
  // Adding id of record being edited to be used by load_edit call
  if (ManageIQ.record.recordId !== null) {
    url += "&id=" + ManageIQ.record.recordId;
  }
  miqJqueryRequest(url);
}

// Attach a calendar control to all text boxes that start with miq_date_
function miqBuildCalendar() {
  // Get all of the input boxes with ids starting with "miq_date_"
  var all = $('input[id^=miq_date_]');

  all.each(function () {
    // Attach dhtmlxcalendars to each one
    var el = $(this);
    var cal = new dhtmlxCalendarObject(el.attr('id'));
    cal.setDateFormat("%m/%d/%Y");

    if ((!el.val()) && ManageIQ.calendar.calDateTo !== null) {
      cal.setDate(ManageIQ.calendar.calDateTo);
    } else {
      cal.setDate(this.value);
    }

    cal.setSkin("dhx_skyblue");
    cal.hideTime();
    cal.setPosition('right');
    // start week from sunday, default is (1) monday
    cal.setWeekStartDay(7);

    if ((typeof ManageIQ.calendar.calDateFrom != "undefined") &&
        (typeof ManageIQ.calendar.calDateTo != "undefined")) {
      cal.setSensitiveRange(ManageIQ.calendar.calDateFrom, ManageIQ.calendar.calDateTo);
    } else if ((typeof ManageIQ.calendar.calDateFrom != "undefined") &&
               (typeof ManageIQ.calendar.calDateTo == "undefined")) {
      cal.setSensitiveRange(ManageIQ.calendar.calDateFrom);
    }
    if (typeof miq_cal_skipDays != "undefined" &&
        miq_cal_skipDays != null &&
        miq_cal_skipDays) {
      cal.setInsensitiveRange(miq_cal_skipDays);
    }

    // Create an observer for the date field if the html5 attr is specified
    if (this.getAttribute('data-miq_observe_date')) {
      el.change(function () {
      miqSendDateRequest(el);
    });
      cal.attachEvent("onClick", function () {
      miqSendDateRequest(el);
      });
    }
  });
}

function miqSendDateRequest(el) {
  var parms = $.parseJSON(el.attr('data-miq_observe_date'));
  var url = parms.url;
  //  tack on the id and value to the URL
  var urlstring = url + '?' + el.prop('id') + '=' + el.val();

  if (parms.auto_refresh === true) {
    dialogFieldRefresh.triggerAutoRefresh(parms.field_id, parms.trigger);
  }

  if (el.attr('data-miq_sparkle_on')) {
    miqJqueryRequest(urlstring, {beforeSend: true});
  } else {
    miqJqueryRequest(urlstring);
  }
}

// Build an explorer view using a YUI layout and a jQuery accordion
function miqBuildExplorerView(options) {
  // Set the default values in the object, then extend it to include the values that we passed to it.
  var settings = $.extend({
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
  }, options || {}); // If no options, pass an empty object

  $(function() {
    // On doc ready, build the layout and accordion
    // Build object for center layout unit settings
    var centerHash = {
      position: 'center'
    };

    // Only add header if option specified (because passing header:null still shows a thin header)
    if (settings.header != null) {
      centerHash.header = settings.header;
    }

    // Build the layout
    if (!settings.left) {
      // If no saved width, calculate
      settings.left = settings.width / settings.divider;
    }

    var expLayout = new YAHOO.widget.Layout(settings.layout_div, {
      units: [
        {
          position: 'left',
          width: settings.left,
          body: settings.left_div,
          collapse: false,
          gutter: '0 5 0 0',
          resize: settings.resize,
          minWidth: settings.width / 8,
          maxWidth: settings.width / 2
        },
        centerHash
      ]
    });

    expLayout.on('render', function () {
      if ($('#main_div').length) {
        miqBuildMainLayout(this, settings.header);
      }
    });

    expLayout.render();

    // Show the layout divs right after layout rendering
    $("#" + settings.center_div).show();
    $("#" + settings.left_div).show();

    // Set up event to capture center layout resize
    var clu = expLayout.getUnitByPosition('center');
    clu.addListener('leftChange', miqExplorerResize);

    // Build the accordion
    $("#" + settings.left_div).accordion({
      change: function (event, ui) {
        miqAccordionChange(event, ui, settings.accord_url);
      },
      fillSpace: true,
      active: "#" + settings.active_accord,
      icons: false,
      animated: false
    });
  });
}

// Build the nested GTL layout inside the explorer layout
function miqBuildMainLayout(parentLayout, header) {
  var el = parentLayout.getUnitByPosition('center').get('wrap');
  var paging_height;

  if ($('#paging_div').length) {
    paging_height = 35;
  } else {
    paging_height = 0;
  }

  var mainLayout = new YAHOO.widget.Layout(el, {
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

  $("#main_div").show();
  $("#taskbar_div").show();
  $("#paging_div").show();
}

function miqExplorerResize(e) {
  var url = "/dashboard/window_sizes";
  var args = {'exp_controller': ManageIQ.controller, 'exp_left': e.newValue}
  // Send the new values to the server
  miqJqueryRequest(miqPassFields(url, args));
}

function miqAccordionChange(event, ui, url) {
  return miqAjaxRequest(ui.newHeader.context.id, url);
}

function miqSetLayoutHeader(unitId, text) {
  return YAHOO.widget.LayoutUnit.getLayoutUnitById(unitId).set('header', text);
}

// common function to pass ajax request to server
function miqAjaxRequest(itemId, path) {
  if (miqCheckForChanges()) {
    miqJqueryRequest(
      miqPassFields(path, {id: itemId}),
      {beforeSend: true, complete: true});
    return true;
  } else {
    return false;
  }
}

// Handle an element onclick to open href in a new window with optional confirmation
function miqClickAndPop(el) {
  var conmsg = el.getAttribute("data-miq_confirm");

  if (conmsg == null || confirm(conmsg)) {
    window.open(el.href);
  }
  // no default browser reaction for onclick
  return false;
}

function miq_tabs_init(id, url) {
  $(id + ' > ul.nav-tabs a[data-toggle="tab"]').on('show.bs.tab', function (e) {
    if ($(e.target).parent().hasClass('disabled')) {
      e.preventDefault();
      return false;
    } else {
      // Load remote tab if an URL is specified
      if (typeof(url) != 'undefined') {
        var currTabTarget = $(e.target).attr('href').substring(1);
        miqJqueryRequest(url + '/?tab_id=' + currTabTarget, {beforeSend: true});
      }
    }
  });
  $(id + ' > ul.nav-tabs a[data-toggle="tab"]').on('shown.bs.tab', function (e) {
    // Refresh CodeMirror when its tab is toggled
    if ($($(e.target).attr('href')).hasClass('cm-tab') && typeof(miqEditor) != 'undefined') {
      miqEditor.refresh();
    }
    // Show buttons according to the show/hide-buttons class
    if ($($(e.target).attr('href')).hasClass('show-buttons')) {
      $("#center_buttons_div").show();
    } else if ($($(e.target).attr('href')).hasClass('hide-buttons')) {
      $("#center_buttons_div").hide();
    }
  });
  // If no active tab is present, set the first tab as active
  if ($(id + ' > ul.nav-tabs li.active:not(.hidden)').length != 1) {
    var tab = $(id + ' > ul.nav-tabs li:not(.hidden)').first().addClass('active');
    $(tab.find('a').attr('href')).addClass('active');
  }
  // Hide the tab header when there is only one visible tab available
  if ($(id + ' > ul.nav-tabs > li:not(.hidden)').length == 1) {
    $(id + ' > ul.nav-tabs').hide();
  }
}

function miq_tabs_disable_inactive(id) {
  $(id + ' ul.nav-tabs > li:not(.active)').addClass('disabled');
}

function miq_tabs_show_hide(tab_id, show) {
  $(tab_id).toggleClass('hidden', !show);
}

// Send explorer search by name via ajax
function miqSearchByName(button) {
  if (button == null) {
    miqJqueryRequest('x_search_by_name', {beforeSend: true, data: miqSerializeForm('searchbox')});
  }
}

// Send search by filter via ajax
function miqSearchByFilter(button) {
  if (button == null) {
    miqJqueryRequest('list_view_filter', {beforeSend: true, data: miqSerializeForm('filterbox')});
  }
}

// Send transaction to server so automate tree selection box can be made active
// and rest of the screen can be blocked
function miqShowAE_Tree(typ) {
  miqJqueryRequest(miqPassFields("ae_tree_select_toggle", {typ: typ}));
  return true;
}

// Use the jQuery.form plugin for ajax file upload
function miqInitJqueryForm() {
  $('#uploadForm input').change(function () {
    $(this).parent().ajaxSubmit({
      beforeSubmit: function (a, f, o) {
        o.dataType = 'script';
        miqSparkleOn();
      }
    });
  });
}

// Launch the VNC Console using the miqvncplugin
function miqLaunchMiqVncConsole(pwd, hostAddress, hostPort, proxyAddress, proxyPort) {
  if (typeof miqvncplugin != "undefined" &&
      typeof miqvncplugin.launchVnc != "undefined") {
    miqSparkleOn();
    miqvncplugin.launchVnc(pwd, hostAddress, hostPort, proxyAddress, proxyPort);
    miqSparkleOff();
  } else {
    alert("The MIQ VNC plugin is not installed");
  }
}

// Toggle the user options div in the page header
function miqToggleUserOptions(id) {
  miqJqueryRequest(miqPassFields("/dashboard/change_group", {to_group: id}));
}

// Check for enter/escape on quick search box
function miqQsEnterEscape(e) {
  var keycode;

  if (window.event) {
    keycode = window.event.keyCode;
  } else if (e) {
    keycode = e.keyCode;
  } else {
    return false;
  }

  if (keycode == 13) {
    if ($('#apply_button').is(':visible')) {
      miqAjaxButton('quick_search?button=apply');
    }
  }

  if (keycode == 27) {
    miqAjaxButton('quick_search?button=cancel');
  }
}

// Start/stop the JS spinner
function miqSpinner(status) {
  if (status) {
    if (ManageIQ.spinner.spinner === null) {
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
        className: 'miq-spinner', // The CSS class to assign to the spinner
        zIndex: 2e9, // The z-index (defaults to 2000000000)
        top: 'auto', // Top position relative to parent in px
        left: 'auto' // Left position relative to parent in px
      };
      ManageIQ.spinner.spinner = new Spinner(opts).spin($('#spinner_div')[0]);
    } else {
      ManageIQ.spinner.spinner.spin($('#spinner_div')[0]);
    }
  } else {
    if (ManageIQ.spinner.spinner !== null) {
      ManageIQ.spinner.spinner.stop();
    }
  }
}

// Start/stop the search spinner
function miqSearchSpinner(status) {
  if (status) {
    if ($('#search_notification').length) {
      $('#search_notification').show();
    }
    if (ManageIQ.spinner.searchSpinner === null) {
      var opts = {
        lines: 13, // The number of lines to draw
        length: 20, // The length of each line
        width: 10, // The line thickness
        radius: 30, // The radius of the inner circle
        corners: 1, // Corner roundness (0..1)
        rotate: 0, // The rotation offset
        direction: 1, // 1: clockwise, -1: counterclockwise
        color: '#000', // #rgb or #rrggbb or array of colors
        speed: 1, // Rounds per second
        trail: 60, // Afterglow percentage
        shadow: false, // Whether to render a shadow
        hwaccel: false, // Whether to use hardware acceleration
        className: 'miq-spinner', // The CSS class to assign to the spinner
        zIndex: 2e9, // The z-index (defaults to 2000000000)
        top: 'auto', // Top position relative to parent in px
        left: 'auto' // Left position relative to parent in px
      };
      ManageIQ.spinner.searchSpinner = new Spinner(opts).spin($('#searching_spinner_center')[0]);
    } else {
      ManageIQ.spinner.searchSpinner.spin($('#searching_spinner_center')[0]);
    }
  } else {
    if ($('#search_notification').length) {
      $('#search_notification').hide();
    }
    if (ManageIQ.spinner.searchSpinner !== null) {
      ManageIQ.spinner.searchSpinner.stop();
    }
  }
}

/*
 * Registers a callback which copies the csrf token into the
 * X-CSRF-Token header with each ajax request.  Necessary to
 * work with rails applications which have fixed
 * CVE-2011-0447
 */
$(document).ajaxSend(function (event, request, settings) {
  var csrf_meta_tag = $('#meta[name=csrf-token]')[0];
  if (csrf_meta_tag) {
    var header = 'X-CSRF-Token';
    var token = csrf_meta_tag.readAttribute('content');
  }
});

function miqJqueryRequest(url, options) {
  options = options || {};
  var ajax_options = {};

  if (options.dataType === undefined) {
    ajax_options.accepts = {script: '*/*;q=0.5, ' + $.ajaxSettings.accepts.script};
    ajax_options.dataType = 'script';
  }

  if (options.data) {
    ajax_options.data = options.data;
  }
  if (options.beforeSend) {
    ajax_options.beforeSend = function (request) {
      miqSparkle(true);
    };
  }
  if (options.complete) {
    ajax_options.complete = function (request) {
      miqSparkle(false);
    };
  }
  $.ajax(options.no_encoding ? url : encodeURI(url), ajax_options);
}

function miqDomElementExists(element) {
  return $('#' + element).length;
}

function miqSerializeForm(element) {
  return $('#' + element).find('input,select,textarea').serialize();
}

function miqSerializeField(element, field_name) {
  return $("#" + element + " :input[id=" + field_name + "]").serialize();
}

function miqInitSelectPicker() {
  $('.selectpicker').selectpicker();
  $('.selectpicker').selectpicker({
    style: 'btn-info',
    size: 4
  });
}

function miqSelectPickerEvent(element, url){
  $('#' + element).on('change', function(){
    var selected = $('#' + element).val();
    miqJqueryRequest(url + '?' + element + '=' + selected);
    return true;
  });
}
