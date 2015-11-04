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

  // Track the mouse coordinates for popup menus
  $(document).mousemove(function (e) {
    ManageIQ.mouse.x = e.pageX;
    ManageIQ.mouse.y = e.pageY;
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

  // Init the toolbars
  if (typeof miqInitToolbars == "function") {
    miqInitToolbars();
  }

  // Refresh the myCodeMirror editor
  if (ManageIQ.editor !== null) {
    ManageIQ.editor.refresh();
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
  $('#toolbar').hide();
  $('#' + tree).dynatree('disable');
  miqDimDiv(tree + '_div', true);
}

// Things to be done on page resize
function miqOnResize() {
  if (typeof dhxLayoutB != "undefined") {
    dhxLayoutB.setSizes();
  }
  miqBrowserSizeTimeout();
}

// Initialize the widget pulldown on the dashboard
function miqInitWidgetPulldown() {
  $("#dashboard_dropdown #toolbar button:not(.dropdown-toggle), #toolbar ul.dropdown-menu > li > a").click(miqWidgetToolbarClick);
}

function miqCalendarDateConversion(server_offset) {
  return moment().utcOffset(Number(server_offset) / 60);
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
    if (typeof ManageIQ.grids.gtl_list_grid == 'undefined' &&
        ($("input[id^='listcheckbox']").length)) {
      // No list_grid on the screen
      var cbs = $("input[id^='listcheckbox']")
      cbs.prop('checked', state);
      miqUpdateButtons(cbs[0], button_div);
    } else if (typeof ManageIQ.grids.gtl_list_grid == 'undefined' &&
               $("input[id^='storage_cb']").length) {
      // to handle check/uncheck all for C&U collection
      $("input[id^='storage_cb']").prop('checked', state);
      miqJqueryRequest(miqPassFields(
        "/configuration/form_field_changed",
        {storage_cb_all: state}
      ));
      return true;
    } else {
      miqGridCheckAll(state);
      var crows = miqGridGetCheckedRows();

      $('#miq_grid_checks').val(crows.join(','));
      miqSetButtons(crows.length, button_div);
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

// Set button enabled or disabled according to the number of selected items
function miqButtonOnWhen(button, onwhen, count) {
  if (typeof onwhen != "undefined") {
    var toggle = true;
    switch(onwhen) {
      case 1:
      case '1':
        toggle = count == 1;
        break;
      case '1+':
        toggle = count >= 1;
        break;
      case '2+':
        toggle = count >= 2;
        break;
    }
    button.toggleClass('disabled', !toggle);
  }
}

// Set the buttons in a div based on the count of checked items passed in
function miqSetButtons(count, button_div) {

  if (button_div.match("_tb$")) {
    var toolbar = $('#' + button_div);

    // Non-dropdown master buttons
    toolbar.find('button:not(.dropdown-toggle)').each(function (k, v) {
      var button = $(v);
      miqButtonOnWhen(button, button.data('onwhen'), count);
    });

    // Dropdown master buttons
    toolbar.find('button.dropdown-toggle').each(function (k, v) {
      var button = $(v);
      miqButtonOnWhen(button, button.data('onwhen'), count);
    });

    // Dropdown button items
    toolbar.find('ul.dropdown-menu > li > a').each(function (k, v) {
      var button = $(v);
      miqButtonOnWhen(button.parent(), button.data('onwhen'), count);
    });

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

// go to the specified URL when a table cell is clicked
function DoNav(theUrl) {
  document.location.href = theUrl;
}

// Routines to get the size of the window
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
  var h = sizes[1] - offset;
  var url = "/dashboard/window_sizes";
  var args = {width: sizes[0], height: sizes[1]};

  if (h < 200) {
    h = 200;
  }

  // Adjust certain elements, if present
  if ($('#list_grid').length) {
    $('#list_grid').css({height: h + 'px'});
  } else if ($('#logview').length) {
    $('#logview').css({height: h + 'px'});
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

// Load XML/SWF charts data (non-IE)
// This method is called by the XML/SWF charts when a chart is loaded into the DOM
function Loaded_Chart(chart_id) {
  if (ManageIQ.browser != 'Explorer') {
    if ((ManageIQ.charts.chartData === null) && (document.readyState == "loading")) {
      setTimeout(function() { Loaded_Chart(chart_id) }, 200);
      return;
    }

    if (ManageIQ.charts.chartData !== null) {
      doLoadChart(chart_id, document.getElementsByName(chart_id)[0]);
    }
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
  var chart_el_id = id.replace(/^miq_/, 'miq_chart_');
  var chartmenu_el_id = id.replace(/^miq_/, 'miq_chartmenu_');

  if (chart_data[idx].menu != null && chart_data[idx].menu.length) {
    var rowcolidx = "_" + row + "-" + col + "-" + idx;

    for (var i = 0; i < chart_data[idx].menu.length; i++) {
      var menu_id = chart_data[idx].menu[i].split(":")[0] + rowcolidx;
      var pid = menu_id.split("-")[0];

      if ($('#' + chartmenu_el_id).find('#' + pid).length == 0) {
        $("#" + chartmenu_el_id).append("<li class='dropdown-submenu'>" +
          "<a tabindex='-1' href='#'>" + pid + "</a>" +
          "<ul id='" + pid + "' class='dropdown-menu'></ul></li>");
      }

      var menu_title = chart_data[idx].menu[i].split(":")[1];
      menu_title = menu_title.replace("<series>", series);
      menu_title = menu_title.replace("<category>", category);
      $("#" + pid).append("<li><a id='" + menu_id +
        "' href='#' onclick='miqChartMenuClick(this.id)'>" + menu_title + "</a></li>");
    }

    $("#" + chartmenu_el_id).css({'left': ManageIQ.mouse.x, 'top': ManageIQ.mouse.y});
    $('#' + chartmenu_el_id).dropdown('toggle');
    $('#' + chart_el_id).find('.overlay').show();
  }
}

// Handle chart context menu clicks
function miqChartMenuClick(itemId) {
  if ($('#menu_div').length) {
    $('#menu_div').hide();
  }
  if (itemId != "cancel") {
    miqAsyncAjax("?menu_click=" + itemId);
  }
}

function miqRESTAjaxButton(url, button, data) {
  var form = $(button).parents('form:first')[0];
  if (form) {
    $(form).submit(function(e) {
      e.preventDefault();
      return false;
    });
    if(data != undefined) {
      formData = data;
    }
    else {
      formData = $(form).serialize();
    }
    miqJqueryRequest(form.action, {
      beforeSend: true,
      complete: true,
      data: formData
    });
  } else {
    miqAjaxButton(url, true);
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
  var data = undefined;

  if (serialize_fields === true) {
    data = miqSerializeForm('form_div');
  } else if (serialize_fields) {  // object or possibly FormData
    data = serialize_fields;
  }

  miqJqueryRequest(url, {beforeSend: true, complete: true, data: data});
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

// Initialize dashboard column jQuery sortables
function miqInitDashboardCols() {
  if ($('#col1').length) {
    $('#col1').sortable({connectWith: '#col2, #col3', handle: "h3"});
    $('#col1').off('sortupdate');
    $('#col1').on('sortupdate', miqDropComplete);
  }
  if ($('#col2').length) {
    $('#col2').sortable({connectWith: '#col1, #col3', handle: "h3"});
    $('#col2').off('sortupdate');
    $('#col2').on('sortupdate', miqDropComplete);
  }
  if ($('#col3').length) {
    $('#col3').sortable({connectWith: '#col1, #col2', handle: "h3"});
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
    var element = $(this);
    var observeDateBackup = null;

    if (! element.data('datepicker')) {
      observeDateBackup = ManageIQ.observeDate;
      ManageIQ.observeDate = function() {};
      element.datepicker();
    }

    if (ManageIQ.calendar.calDateFrom) {
      element.datepicker('setStartDate', ManageIQ.calendar.calDateFrom);
    }

    if (ManageIQ.calendar.calDateTo) {
      element.datepicker('setEndDate', ManageIQ.calendar.calDateTo);
    }

    if (ManageIQ.calendar.calSkipDays) {
      element.datepicker('setDaysOfWeekDisabled', ManageIQ.calendar.calSkipDays);
    }

    if (observeDateBackup != null) {
      ManageIQ.observeDate = observeDateBackup;
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
    if ($($(e.target).attr('href')).hasClass('cm-tab') && typeof(ManageIQ.editor) != 'undefined') {
      ManageIQ.editor.refresh();
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
  else if ($(id + ' > ul.nav-tabs > li:not(.hidden)').length > 1) {
    $(id + ' > ul.nav-tabs').show();
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

// Send transaction to server so automate tree selection box can be made active
// and rest of the screen can be blocked
function miqShowAE_Tree(typ) {
  miqJqueryRequest(miqPassFields("ae_tree_select_toggle", {typ: typ}));
  return true;
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
  return $('#' + element).find('input,select,textarea').serialize().replace(/%0D%0A/g, '%0A');
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
  $('.bootstrap-select > button[title]').not('.selectpicker').tooltip({container: 'none'});
}

function miqSelectPickerEvent(element, url, options){
  $('#' + element).on('change', function(){
    var selected = $('#' + element).val();
    options =  typeof options !== 'undefined' ? options : {}
    options['no_encoding'] = true;
    miqJqueryRequest(url + '?' + element + '=' + escape(selected), options);
    return true;
  });
}

function miqAccordSelect(e) {
  if (!miqCheckForChanges()) {
    return false;
  } else {
    var url = '/' + $('body').data('controller') + '/accordion_select?id=' + $(e.target).attr('id');
    miqJqueryRequest(url, {beforeSend: true, complete: true});
    return true;
  }
}

// This function is called in miqOnLoad
function miqInitToolbars() {
  $("#toolbar button:not(.dropdown-toggle), #toolbar ul.dropdown-menu > li > a, #toolbar .toolbar-pf-view-selector > ul.list-inline > li > a").off('click');
  $("#toolbar button:not(.dropdown-toggle), #toolbar ul.dropdown-menu > li > a, #toolbar .toolbar-pf-view-selector > ul.list-inline > li > a").click(miqToolbarOnClick);
}

// Function to run transactions when toolbar button is clicked
function miqToolbarOnClick(e) {
  var tb_url;
  var button = $(this);

  // If it's a dropdown, collapse the parent container
  var parent = button.parents('div.btn-group.dropdown.open');
  parent.removeClass('open');
  parent.children('button.dropdown-toggle').attr('aria-expanded', 'false');

  if (button.hasClass('disabled') || button.parent().hasClass('disabled')) {
    return;
  }

  if (button.parents('#dashboard_dropdown').length > 0) {
    return;
  }

  if (button.data("confirm") && !button.data("popup")) {
    if (!confirm(button.data('confirm'))) {
      return;
    }
  } else if (button.data("confirm") && button.data("popup")) {
    // to open console in a new window
    if (confirm(button.data('confirm'))) {
      if (button.data('popup') != "undefined" && button.data('popup')) {
        if (button.data("console_url")) {
          window.open(button.data('console_url'));
        }
      }
    }
    return;
  } else if (!button.data("confirm") && button.data("popup")) {
    // to open readonly report in a new window, doesnt have confirm message
    if (button.data('popup')) {
      if (button.data("console_url")) {
        window.open(button.data('console_url'));
      }
    }
    return;
  }

  if (button.data("url")) {
    // See if a url is defined
    if (button.data('url').indexOf("/") === 0) {
      // If url starts with / it is non-ajax
      tb_url = "/" + ManageIQ.controller + button.data('url');
      if (ManageIQ.record.recordId !== null) {
        tb_url += "/" + ManageIQ.record.recordId;
      }
      if (button.data("url_parms")) {
        tb_url += button.data('url_parms');
      }
      DoNav(encodeURI(tb_url));
      return;
    } else {
      // An ajax url was defined
      tb_url = "/" + ManageIQ.controller + "/" + button.data('url');
      if (button.data('url').indexOf("x_history") !== 0) {
        // If not an explorer history button
        if (ManageIQ.record.recordId !== null) {
          tb_url += "/" + ManageIQ.record.recordId;
        }
      }
    }
  } else {
    // No url specified, run standard button ajax transaction
    if (typeof button.data('explorer') != "undefined" && button.data('explorer')) {
      // Use x_button method for explorer ajax
      tb_url = "/" + ManageIQ.controller + "/x_button";
    } else {
      tb_url = "/" + ManageIQ.controller + "/button";
    }
    if (ManageIQ.record.recordId !== null) {
      tb_url += "/" + ManageIQ.record.recordId;
    }
    tb_url += "?pressed=";
    if (typeof button.data('pressed') == "undefined") {
      tb_url += button.data('click').split("__").pop();
    } else {
      tb_url += button.data('pressed');
    }
  }

  collect_log_buttons = [ 'support_vmdb_choice__collect_logs',
                          'support_vmdb_choice__collect_current_logs',
                          'support_vmdb_choice__zone_collect_logs',
                          'support_vmdb_choice__zone_collect_current_logs'
  ];
  if (jQuery.inArray(button.attr('name'), collect_log_buttons) >= 0 && button.data('prompt')) {
    tb_url = miqSupportCasePrompt(tb_url);
    if (!tb_url) {
      return false;
    }
  }

  // put url_parms into params var, if defined
  var params;
  if (button.data("url_parms")) {
    if (button.data('url_parms').match("_div$")) {
      if (miqDomElementExists('miq_grid_checks')) {
        params = "miq_grid_checks=" + $('#miq_grid_checks').val();
      } else {
        params = miqSerializeForm(button.data('url_parms'));
      }
    } else {
      params = button.data('url_parms').split("?")[1];
    }
  }

  // TODO:
  // Checking for perf_reload button to not turn off spinning Q (will be done after charts are drawn).
  // Need to design this feature into the toolbar button support at a later time.
  if ((button.attr('name') == "perf_reload") ||
      (button.attr('name') == "vm_perf_reload") ||
      (button.attr('name').match("_console$"))) {
    if (typeof params == "undefined") {
      miqJqueryRequest(tb_url, {beforeSend: true});
    } else {
      miqJqueryRequest(tb_url, {beforeSend: true, data: params});
    }
  } else {
    if (typeof params == "undefined") {
      miqJqueryRequest(tb_url, {beforeSend: true, complete: true});
    } else {
      miqJqueryRequest(tb_url, {beforeSend: true, complete: true, data: params});
    }
  }
  return false;
}

function miqSupportCasePrompt(tb_url) {
  var support_case = prompt('Enter Support Case:', '');
  if (support_case === null) {
    return false;
  } else if (support_case.trim() == '') {
    alert('Support Case must be provided to collect logs');
    return false;
  } else {
    tb_url = tb_url + '&support_case=' + encodeURIComponent(support_case);
    return tb_url;
  }
}

// Handle chart context menu clicks
function miqWidgetToolbarClick(e) {
  var itemId = $(this).data('click');
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
