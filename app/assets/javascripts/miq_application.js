/* global dialogFieldRefresh jqplot_bind_events miqBrowserDetect miqExpressionPrefill miqGridCheckAll miqGridGetCheckedRows miqLoadTL miqMenu miqValueStylePrefill performFiltering */

// MIQ specific JS functions

// Things to be done on page loads
function miqOnLoad() {
  // controller to be used in url in miqDropComplete method
  ManageIQ.widget.dashboardUrl = "dashboard/widget_dd_done";

  // Initialize the dashboard column sortables
  if (miqDomElementExists('col1')) {
    miqInitDashboardCols();
  }

  // Track the mouse coordinates for popup menus
  $(document).mousemove(function (e) {
    ManageIQ.mouse.x = e.pageX;
    ManageIQ.mouse.y = e.pageY;
  });

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

  // Initialize the dashboard widget pulldown
  if (miqDomElementExists('widget_select_div')) {
    miqInitWidgetPulldown();
  }

  // Refresh the myCodeMirror editor
  if (ManageIQ.editor !== null) {
    ManageIQ.editor.refresh();
  }

  // Run MIQ after onload code if present
  if (typeof ManageIQ.afterOnload == "string") {
    eval(ManageIQ.afterOnload);
  }

  // Focus on search box, if it's there and allows focus
  if (miqDomElementExists('search_text')) {
    try {
      $('#search_text').focus();
    } catch (_e) {}
  }

  miqInitAccordions();
  miqInitMainContent();
}

function miqPrepRightCellForm(tree) {
  if (miqDomElementExists('adv_searchbox_div')) {
    $('#adv_searchbox_div').hide();
  }
  $('#toolbar').hide();
  miqTreeObject(tree).disableAll({silent: true, keepState: true});
  miqDimDiv(tree + '_div', true);
}

// Initialize the widget pulldown on the dashboard
function miqInitWidgetPulldown() {
  $("#dashboard_dropdown button:not(.dropdown-toggle), #toolbar ul.dropdown-menu > li > a").off('click');
  $("#dashboard_dropdown button:not(.dropdown-toggle), #toolbar ul.dropdown-menu > li > a").on('click', miqWidgetToolbarClick);
}

function miqCalendarDateConversion(server_offset) {
  return moment().utcOffset(Number(server_offset) / 60);
}

// The expressions variable is used only in the following two functions
// TODO: Remove this scope wrapper after the expressions were moved to Ruby
(function () {
  // TODO: This probably should be moved into the Ruby code
  var expressions = {
    'boolean':     __('true/false'),
    'bytes':       __('Number (Bytes)'),
    'date':        __('Date'),
    'datetime':    __('Date/Time'),
    'decimal':     __('Integer'),
    'fixnum':      __('Integer'),
    'float':       __('Number'),
    'gigabytes':   __('Number (GB)'),
    'integer':     __('Integer'),
    'kbps':        __('KBps'),
    'kilobytes':   __('Number (kB)'),
    'megabytes':   __('Number (MB)'),
    'mhz':         __('MHz'),
    'mhz_avg':     __('MHz'),
    'numeric_set': __('Number List'),
    'percent':     __('Percent'),
    'regex':       __('Text (REGEX)'),
    'ruby':        __('Ruby Script'),
    'string':      __('Text'),
    'string_set':  __('String List'),
    'text':        __('Text')
  };

  // Prefill expression value text entry fields when blank
  window.miqExpressionPrefill = function (expEditor, noPrefillCount) {
    var title;


    if ($('#chosen_value[type=text]').length) {
      $('#chosen_value').prop('placeholder', expressions[expEditor.first.type])
      $('#chosen_value').prop('title', expEditor.first.title);
      $('#chosen_value').prop('alt', expEditor.first.title);
    }
    if ($('#chosen_cvalue[type=text]').length) {
      $('#chosen_cvalue').prop('placeholder', expressions[expEditor.second.type])
      $('#chosen_cvalue').prop('title', expEditor.second.title);
      $('#chosen_cvalue').prop('alt', expEditor.second.title);
    }
    if ($('#chosen_regkey[type=text]').length) {
      title = __("Registry Key");
      $('#chosen_regkey').prop('placeholder', expressions['string']);
      $('#chosen_regkey').prop('title', title);
      $('#chosen_regkey').prop('alt', title);
    }
    if ($('#chosen_regval[type=text]').length) {
      title = __("Registry Key Value");
      $('#chosen_regval').prop('placeholder', expressions['string']);
      $('#chosen_regval').prop('title', title);
      $('#chosen_regval').prop('alt', title);
    }
    if ($('#miq_date_1_0[type=text]').length) {
      $('#miq_date_1_0').prop('placeholder', expressions[expEditor.first.type]);
      $('#miq_date_1_0').prop('title', expEditor.first.title);
      $('#miq_date_1_0').prop('alt', expEditor.first.title);
    }
    if ($('#miq_date_1_1[type=text]').length) {
      $('#miq_date_1_1').prop('placeholder', expressions[expEditor.first.type]);
      $('#miq_date_1_1').prop('title', expEditor.first.title);
      $('#miq_date_1_1').prop('alt', expEditor.first.title);
    }
    if ($('#miq_date_2_0[type=text]').length) {
      $('#miq_date_2_0').prop('placeholder', expressions[expEditor.second.type]);
      $('#miq_date_2_0').prop('title', expEditor.second.title);
      $('#miq_date_2_0').prop('alt', expEditor.second.title);
    }
    if ($('#miq_date_2_1[type=text]').length) {
      $('#miq_date_2_1').prop('placeholder', expressions[expEditor.second.type]);
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
  window.miqValueStylePrefill = function (count) {
    var found = false;

    for (var field in ManageIQ.reportEditor.valueStyles) {
      if ($(field).length) {
        $(field).prop('placeholder', expressions[ManageIQ.reportEditor.valueStyles[field]]);
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
})();

// Get user's time zone offset
function miqGetTZO() {
  if (miqDomElementExists('user_TZO')) {
    $('#user_TZO').val(moment().utcOffset() / 60);
  }
}

// Get user's browswer info
function miqGetBrowserInfo() {
  var bd = miqBrowserDetect();

  if (miqDomElementExists('browser_name')) {
    $('#browser_name').val(bd.browser);
  }
  if (miqDomElementExists('browser_version')) {
    $('#browser_version').val(bd.version);
  }
  if (miqDomElementExists('browser_os')) {
    $('#browser_os').val(bd.OS);
  }
}

// Turn highlight on or off
function miqHighlight(elem, status) {
  if ($(elem).length) {
    return;
  }

  if (status) {
    $(elem).addClass('active');
  } else {
    $(elem).removeClass('active');
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
  if (miqDomElementExists('advsearchModal') &&
      ($('#advsearchModal').hasClass('modal fade in'))) {
    if (miqDomElementExists('searching_spinner_center')) {
      miqSearchSpinner(true);
    }
    miqSpinner(false);
    if (miqDomElementExists('notification')) {
      $('#notification').hide();
    }
  } else {
    if (miqDomElementExists('notification')) {
      $('#notification').show();
    }
    miqSpinner(true);
  }
}

function miqSparkleOff() {
  miqSpinner(false);
  if (miqDomElementExists('searching_spinner_center')) {
    miqSearchSpinner(false);
  }
  if (miqDomElementExists('notification')) {
    $('#notification').hide();
  }
  if (miqDomElementExists('rep_notification')) {
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
  if (ManageIQ.angular.scope) {
    if (angular.isDefined(ManageIQ.angular.scope.angularForm) &&
      ManageIQ.angular.scope.angularForm.$dirty &&
      !miqDomElementExists('ignore_form_changes')) {
      var answer = confirm(__("Abandon changes?"));
      if (answer) {
        ManageIQ.angular.scope.angularForm.$setPristine(true);
      }
      return answer;
    }
  } else if (((miqDomElementExists('buttons_on') &&
               $('#buttons_on').is(":visible")) ||
              ManageIQ.changes !== null) &&
             !miqDomElementExists('ignore_form_changes')) {
    return confirm(__("Abandon changes?"));
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
  var buttonsOnId = prefix + 'validate_buttons_on';
  var buttonsOffId = prefix + 'validate_buttons_off';

  if (miqDomElementExists('flash_msg_div')) {
    $('flash_msg_div').hide();
  }

  if (h_or_s == "show") {
    if (miqDomElementExists(buttonsOnId)) {
      $('#' + buttonsOnId).show();
    }
    if (miqDomElementExists(buttonsOffId)) {
      $('#' + buttonsOffId).hide();
    }
  } else {
    if (miqDomElementExists(buttonsOffId)) {
      $('#' + buttonsOffId).show();
    }
    if (miqDomElementExists(buttonsOnId)) {
      $('#' + buttonsOnId).hide();
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
// parms: button_div=<id of div with buttons to update>
function miqUpdateAllCheckboxes(button_div) {
  if (!miqDomElementExists('masterToggle'))
    return;

  var state = $('#masterToggle').prop('checked');

  if (ManageIQ.grids.gtl_list_grid) {
    miqGridCheckAll(state);
    var crows = miqGridGetCheckedRows();

    ManageIQ.gridChecks = crows;
    miqSetButtons(crows.length, button_div);
  } else if ($("input.listcheckbox").length) {
    // No list_grid on the screen
    var cbs = $("input.listcheckbox")
      .prop('checked', state)
      .trigger('change');

    miqUpdateButtons(cbs[0], button_div);
  } else if ($("input[id^='storage_cb']").length) {
    // to handle check/uncheck all for C&U collection
    $("input[id^='storage_cb']")
      .prop('checked', state)
      .trigger('change');
    miqJqueryRequest(miqPassFields(
      "/configuration/form_field_changed",
      {storage_cb_all: state}
    ));
  }
}

// Update buttons based on number of checkboxes that are checked
// parms: obj=<checkbox element>, button_div=<id of div with buttons to update>
function miqUpdateButtons(obj, button_div) {
  var count = 0;

  sendDataWithRx({rowSelect: obj});

  if (typeof obj.id != "undefined") {
    $("input[id^='check_']").each(function () {
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
  if (!miqDomElementExists(button_div)) {
    return
  }

  if (button_div.match("_tb$")) {
    var toolbar = $('#' + button_div);

    // Non-dropdown master buttons
    toolbar.find('button:not(.dropdown-toggle)').each(function (_k, v) {
      var button = $(v);
      miqButtonOnWhen(button, button.data('onwhen'), count);
    });

    // Dropdown master buttons
    toolbar.find('button.dropdown-toggle').each(function (_k, v) {
      var button = $(v);
      miqButtonOnWhen(button, button.data('onwhen'), count);
    });

    // Dropdown button items
    toolbar.find('ul.dropdown-menu > li > a').each(function (_k, v) {
      var button = $(v);
      miqButtonOnWhen(button.parent(), button.data('onwhen'), count);
    });
  } else if (button_div.match("_buttons$")) { // Handle buttons that are not part of miq toolbars
    if (count === 0) {
      $("#" + button_div + " button[id$=on_1]").prop('disabled', true);
    } else if (count == 1) {
      $("#" + button_div + " button[id$=on_1]").prop('disabled', false);
    } else {
      $("#" + button_div + " button[id$=on_1]").prop('disabled', false);
    }
  }
}

// go to the specified URL when a table cell is clicked
function DoNav(theUrl) {
  document.location.href = theUrl;
}

// Routines to get the size of the window
function miqResetSizeTimer() {
  var height = window.innerHeight;
  var offset = 427;
  var h = height - offset;

  if (h < 200) {
    h = 200;
  }

  // Adjust certain elements, if present
  if (miqDomElementExists('list_grid')) {
    $('#list_grid').css({height: h + 'px'});
  } else if (miqDomElementExists('logview')) {
    $('#logview').css({height: h + 'px'});
  }
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

function miqBuildChartMenu(col, row, _value, category, series, id, _message) {
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

function miqChartBindEvents(chart_set, chart_index) {
  if (ManageIQ.charts.provider == 'jqplot') {
    jqplot_bind_events(chart_set, chart_index);
  } else if (ManageIQ.charts.provider == 'c3') {
    // noop
  }
}

function miqBuildChartMenuEx(col, row, _value, category, series, chart_set, chart_index) {
  var chart_data = ManageIQ.charts.chartData[chart_set];
  var chart_el = $('#miq_chart_parent_' + chart_set + '_' + chart_index);
  var chartmenu_el = $('#miq_chartmenu_' + chart_set + '_' + chart_index);
  chartmenu_el.empty();

  if (chart_data[chart_index].menu != null && chart_data[chart_index].menu.length) {
    var row_col_chart_index = {
      row: row,
      column: col,
      chart_index: chart_index,
    };
    for (var i = 0; i < chart_data[chart_index].menu.length; i++) {
      row_col_chart_index['chart_name'] = chart_data[chart_index].menu[i].split(":")[0];
      var pid = row_col_chart_index['chart_name'].split("-")[0];
      if (chartmenu_el.find('#' + pid).length == 0) {
        chartmenu_el.append("<li class='dropdown-submenu'>" +
          "<a tabindex='-1' href='#'>" + pid + "</a>" +
          "<ul id='" + pid + "' class='dropdown-menu'></ul></li>");
      }

      var menu_title = chart_data[chart_index].menu[i].split(":")[1];
      menu_title = menu_title.replace("<series>", series);
      menu_title = menu_title.replace("<category>", category);
      $("#" + pid).append("<li><a id='"+btoa(JSON.stringify(row_col_chart_index))+"' href='#' onclick='miqChartMenuClick(this.id)'>" + menu_title + "</a></li>");
    }

    //chart menu has min-width: 160 a has two levels
    var x_position = (ManageIQ.mouse.x > $(window).width() - 320) ? $(window).width() - 320 : ManageIQ.mouse.x;
    chartmenu_el.css({'left': x_position, 'top': ManageIQ.mouse.y});
    chartmenu_el.dropdown('toggle');
    chart_el.find('.overlay').show();
  }
}

// Handle chart context menu clicks
function miqChartMenuClick(itemId) {
  if (miqDomElementExists('menu_div')) {
    $('#menu_div').hide();
  }
  if (itemId != "cancel") {
    miqAsyncAjax("?menu_click=" + itemId);
  }
}

function miqRESTAjaxButton(url, button, dataType, data) {
  var form = $(button).parents('form:first')[0];
  if (form) {
    $(form).submit(function(e) {
      e.preventDefault();
      return false;
    });
    var formData;
    if(data != undefined) {
      formData = data;
    } else {
      formData = $(form).serialize();
    }
    return miqJqueryRequest(url, {
      beforeSend: true,
      complete: true,
      data: formData,
      dataType: dataType
    });
  } else {
    miqAjaxButton(url, true);
  }
}

// Handle an ajax form button press (i.e. Submit) by starting the spinning Q,
// then waiting for .7 seconds for observers to finish
function miqAjaxButton(url, serialize_fields, options) {
  if (typeof serialize_fields == "undefined") {
    serialize_fields = false;
  }
  if (miqDomElementExists('notification')) {
    $('#notification').show();
  }

  setTimeout(function () {
    miqAjaxButtonSend(url, serialize_fields, options);
  }, 700);
}

// Send ajax url after any outstanding ajax requests, wait longer if needed
function miqAjaxButtonSend(url, serialize_fields, options) {
  if ($.active) {
    setTimeout(function () {
      miqAjaxButtonSend(url, serialize_fields, options);
    }, 700);
  } else {
    miqAjax(url, serialize_fields, options);
  }
}

// Function to generate an Ajax request
function miqAjax(url, serialize_fields, options) {
  var data = undefined;

  if (serialize_fields === true) {
    data = miqSerializeForm('form_div');
  } else if (serialize_fields) {  // object or possibly FormData
    data = serialize_fields;
  }

  var defaultOptions = {
    beforeSend: true,
    complete: true,
  };

  miqJqueryRequest(url, _.extend(defaultOptions, options || {}, { data: data }))
    .catch(function(err){
      add_flash(__("Error requesting data from server"), 'error');
      console.log(err);
      return Promise.reject(err)
    });
}

// Function to generate an Ajax request for EVM async processing
function miqAsyncAjax(url) {
  miqJqueryRequest(url, {beforeSend: true});
}

ManageIQ.oneTransition.oneTrans = 0;

// Function to generate an Ajax request, but only once for a drawn screen
function miqSendOneTrans(url, observe) {
  if (ManageIQ.oneTransition.IEButtonPressed) {
    // page replace after clicking save/reset was making observe_field on
    // text_area in IE send up a trascation to form_field_changed method
    ManageIQ.oneTransition.IEButtonPressed = false;
    return;
  }
  if (ManageIQ.oneTransition.oneTrans) {
    return;
  }

  ManageIQ.oneTransition.oneTrans = 1;

  if (observe && observe.observe) {
    return miqObserveRequest(url, { done: observe.done });
  } else {
    return miqJqueryRequest(url);
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
    $('#' + counter).text(obj.value.length);
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
function miqAjaxAuth(url) {
  miqEnableLoginFields(false);
  miqSparkleOn(); // miqJqueryRequest starts sparkle either way, but API.login doesn't

  var credentials = {
    login: $('#user_name').val(),
    password: $('#user_password').val(),
    serialized: miqSerializeForm('login_div'),
  }

  API.login(credentials.login, credentials.password)
  .then(function() {
    return API.ws_init();
  })
  .then(function() {
    // API login ok, now do the normal one
    miqJqueryRequest(url || '/dashboard/authenticate', {
      beforeSend: true,
      data: credentials.serialized,
    });

    // TODO API.autorenew is called on (non-login) page load - when?
  })
  .then(null, function() {
    add_flash(__("Incorrect username or password"), 'error', { id: 'auth_failed' });

    miqEnableLoginFields(true);
    miqSparkleOff();
  });
}

// Send SSO login authentication via ajax
function miqAjaxAuthSso(url) {
  miqEnableLoginFields(false);
  miqSparkleOn();

  // Note: /dashboard/kerberos_authenticate creates an API token
  //       based on the authenticated external user
  //       and stores it in sessionStore.miq_token

  miqJqueryRequest(url || '/dashboard/kerberos_authenticate', {
    beforeSend: true,
  });
}

// Send External Authentication via ajax
function miqAjaxExtAuth(url) {
  miqEnableLoginFields(false);
  miqSparkleOn();

  // Note: /dashboard/external_authenticate creates an API token
  //       based on the authenticated external user
  //       and stores it in sessionStore.miq_token

  var credentials = {
    login: $('#user_name').val(),
    password: $('#user_password').val(),
    serialized: miqSerializeForm('login_div'),
  }

  miqJqueryRequest(url || '/dashboard/external_authenticate', {
    beforeSend: true,
    data: credentials.serialized,
  });
}

// add a flash message to an existing #flash_msg_div
// levels are error, warning, info, success
function add_flash(msg, level, options) {
  level = level || 'success';
  options = options || {};
  var cls = { alert: '', icon: '' };

  switch (level) {
    case 'error':
      cls.alert = 'alert alert-danger';
      cls.icon = 'pficon pficon-error-circle-o';
      break;
    case 'warning':
      cls.alert = 'alert alert-warning';
      cls.icon = 'pficon pficon-warning-triangle-o';
      break;
    case 'info':
      cls.alert = 'alert alert-info';
      cls.icon = 'pficon pficon-info';
      break;
    case 'success':
      cls.alert = 'alert alert-success';
      cls.icon = 'pficon pficon-ok';
      break;
  }

  var icon_span = $('<span class="' + cls.icon + '"></span>');

  var text_strong = $('<strong></strong>');
  text_strong.text(msg);

  var alert_div = $('<div class="' + cls.alert + '"></div>');
  alert_div.append(icon_span, text_strong);

  var text_div = $('<div class="flash_text_div"></div>');
  text_div.attr('title', __('Click to remove message'));
  text_div.on('click', function() {
    text_div.remove();
  });
  text_div.append(alert_div);

  // if options.id is provided, only one flash message with that id may exist
  if (options.id) {
    $('#' + options.id).filter('#flash_msg_div > *').remove();
    text_div.attr('id', options.id);
  }

  $('#flash_msg_div').append(text_div).show();
}

function miqEnableLoginFields(enabled) {
  $('#user_name').prop('readonly', !enabled);
  $('#user_password').prop('readonly', !enabled);
  if (miqDomElementExists('user_new_password')) {
    $('#user_new_password').prop('readonly', !enabled);
  }
  if (miqDomElementExists('user_verify_password')) {
    $('#user_verify_password').prop('readonly', !enabled);
  }
}

// Initialize dashboard column jQuery sortables
function miqInitDashboardCols() {
  if (miqDomElementExists('col1')) {
    $('#col1').sortable({connectWith: '#col2, #col3', handle: ".sortable-handle"});
    $('#col1').off('sortupdate');
    $('#col1').on('sortupdate', miqDropComplete);
  }
  if (miqDomElementExists('col2')) {
    $('#col2').sortable({connectWith: '#col1, #col3', handle: ".sortable-handle"});
    $('#col2').off('sortupdate');
    $('#col2').on('sortupdate', miqDropComplete);
  }
  if (miqDomElementExists('col3')) {
    $('#col3').sortable({connectWith: '#col1, #col2', handle: ".sortable-handle"});
    $('#col3').off('sortupdate');
    $('#col3').on('sortupdate', miqDropComplete);
  }
}

// Send the updated sortable order after jQuery drag/drop
function miqDropComplete(_event, _ui) {
  var el = $(this);
  var url = "/" + ManageIQ.widget.dashboardUrl + "?" + el.sortable(
              'serialize', {key: el.attr('id') + "[]"}
            ).toString();
  // dialog service uses div ID for reorder, because unsaved element doesnt have record ID
  if (url.match(/dialog_res_reorder/)) {
    miqUpdateElementsId(el);
  }
  // Adding id of record being edited to be used by load_edit call
  if (ManageIQ.record.recordId !== null) {
    url += "&id=" + ManageIQ.record.recordId;
  }
  miqJqueryRequest(url);
}

function miqUpdateElementsId(el) {
  $(el).children().each(function(idx, el) {
    var el_id = $(el).attr("id").split("|")[1];
    $(el).attr("id", "t_" + idx + "|" + el_id);
  });
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

  var attemptAutoRefreshTrigger = function() {
    if (parms.auto_refresh === true) {
      dialogFieldRefresh.triggerAutoRefresh(parms);
    }
  };

  var options = {
    beforeSend: !! el.attr('data-miq_sparkle_on'),
    complete: !! el.attr('data-miq_sparkle_off'),
    done: attemptAutoRefreshTrigger,
  };

  return miqObserveRequest(urlstring, options);
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
    } else if (typeof(url) != 'undefined') {
      // Load remote tab if an URL is specified
      var currTabTarget = $(e.target).attr('href').substring(1);
      miqJqueryRequest(url + '/?tab_id=' + currTabTarget, {beforeSend: true})
        .catch(function(err){
          add_flash(__("Error requesting data from server"), 'error');
          console.log(err);
          return Promise.reject(err)
      });
    }
  });

  $(id + ' > ul.nav-tabs a[data-toggle="tab"]').on('shown.bs.tab', function (e) {
    // Refresh CodeMirror when its tab is toggled
    if ($($(e.target).attr('href')).hasClass('cm-tab') && typeof(ManageIQ.editor) != 'undefined') {
      ManageIQ.editor.refresh();
    }
  });

  // If no active tab is present, set the first tab as active
  var active_tabs = $(id + ' > ul.nav-tabs li.active:not(.hidden)').length;
  if ( active_tabs > 1) {
    var tab = $(id + ' > ul.nav-tabs li:not(.hidden)').first().removeClass('active');
    $(tab.find('a').attr('href')).removeClass('active');
  } else if (active_tabs != 1) {
    var tab = $(id + ' > ul.nav-tabs li:not(.hidden)').first().addClass('active');
    $(tab.find('a').attr('href')).addClass('active');
  }

  // Hide the tab header when there is only one visible tab available
  if ($(id + ' > ul.nav-tabs > li:not(.hidden)').length == 1) {
    $(id + ' > ul.nav-tabs').hide();
  } else if ($(id + ' > ul.nav-tabs > li:not(.hidden)').length > 1) {
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
  var ae_url = "/" + ManageIQ.controller + "/ae_tree_select_toggle";
  miqJqueryRequest(miqPassFields(ae_url, {typ: typ}));
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
  var opts = {
    lines: 15, // The number of lines to draw
    length: 18, // The length of each line
    width: 4, // The line thickness
    radius: 25, // The radius of the inner circle
    color: '#fff', // #rgb or #rrggbb
    trail: 60, // Afterglow percentage
    className: 'miq-spinner', // The CSS class to assign to the spinner
  };

  $('#spinner_div').spin(status ? opts : false);
}

// Start/stop the search spinner
function miqSearchSpinner(status) {
  var opts = {
    lines: 13, // The number of lines to draw
    length: 20, // The length of each line
    width: 10, // The line thickness
    radius: 30, // The radius of the inner circle
    color: '#000', // #rgb or #rrggbb or array of colors
    trail: 60, // Afterglow percentage
    className: 'miq-spinner', // The CSS class to assign to the spinner
  };

  $('#search_notification').toggle(!! status);
  $('#searching_spinner_center').spin(status ? opts : false);
}

function miqProcessObserveQueue() {
  if (! ManageIQ.observe.queue.length) {
    return;
  }

  if (ManageIQ.observe.processing) {
    setTimeout(miqProcessObserveQueue, 700);
    return;
  }

  ManageIQ.observe.processing = true;

  var request = ManageIQ.observe.queue.shift();

  miqJqueryRequest(request.url, request.options)
  .then(function(arg) {
    ManageIQ.observe.processing = false;
    request.deferred.resolve(arg);
  }, function(err) {
    ManageIQ.observe.processing = false;
    add_flash(__("Error requesting data from server"), 'error');
    console.log(err);
    request.deferred.reject(err);
  });
}

function miqObserveRequest(url, options) {
  options = _.cloneDeep(options || {});
  options.observe = true;

  var deferred = {};
  deferred.promise = new Promise(function(resolve, reject) {
    deferred.resolve = resolve;
    deferred.reject = reject;
  });

  ManageIQ.observe.queue.push({
    url: url,
    options: options,
    deferred: deferred,
  });

  miqProcessObserveQueue();

  return deferred.promise;
}

function miqJqueryRequest(url, options) {
  if ((ManageIQ.observe.processing || ManageIQ.observe.queue.length) && (!options || !options.observe)) {
    console.debug('Postponing miqJqueryRequest - waiting for the observe queue to empty first');

    return new Promise(function(resolve, reject) {
      setTimeout(function() {
        miqJqueryRequest(url, options)
        .then(resolve, reject);
      }, 700);
    });
  }

  options = options || {};
  var ajax_options = {
    type: 'POST',
  };

  if (options.dataType === undefined) {
    ajax_options.accepts = {script: '*/*;q=0.5, ' + $.ajaxSettings.accepts.script};
    ajax_options.dataType = 'script';
  }

  // copy selected options over
  _.extend(ajax_options, _.pick(options, [
    'data',
    'dataType',
    'contentType',
    'processData',
    'cache',
  ]));

  if (options.beforeSend) {
    ajax_options.beforeSend = function (_request) {
      miqSparkle(true);
    };
  }

  var complete = [];
  if (options.complete) {
    complete.push(function (_request) {
      miqSparkle(false);
    });
  }

  if (options.done) {
    complete.push(options.done);
  }

  if (complete.length) {
    ajax_options.complete = complete;
  }

  return new Promise(function(resolve, reject) {
    $.ajax(options.no_encoding ? url : encodeURI(url), ajax_options)
    .then(resolve, reject);
  });
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
  $('.selectpicker').selectpicker({
    size: 10,
    dropupAuto: false
  });
  $('.bootstrap-select > button[title]').not('.selectpicker').tooltip({container: 'none'});
}

function miqInitCodemirror(options) {
  if (! miqDomElementExists(options.text_area_id)) {
    return;
  }

  var textarea = $('#' + options.text_area_id)[0];

  ManageIQ.editor = CodeMirror.fromTextArea(textarea, {
    mode: options.mode,
    lineNumbers: options.line_numbers,
    matchBrackets: true,
    theme: 'eclipse',
    readOnly: options.read_only ? 'nocursor' : false,
    viewportMargin: Infinity,
  });

  ManageIQ.editor.on('change', function (cm, change) {
    if (options.angular) {
      ManageIQ.editor.save();
      $(textarea).trigger("change");
    } else {
      miqSendOneTrans(options.url);
    }
  });

  ManageIQ.editor.on('blur', function (cm, change) {
    ManageIQ.editor.save();
  });

  $('.CodeMirror').css('height', options.height);
  $('.CodeMirror').css('width', options.width);

  if (! options.no_focus) {
    ManageIQ.editor.focus();
  }
}

function miqSelectPickerEvent(element, url, options) {
  options = options || {};
  options.no_encoding = true;
  var firstarg = ! _.contains(url, '?');

  $('#' + element).on('change', _.debounce(function() {
    var selected = $(this).val();
    var finalUrl = url + (firstarg ? '?' : '&') + element + '=' + encodeURIComponent(selected);

    if (typeof $(this).attr('data-miq_sparkle_on') != 'undefined')
      options.beforeSend = $(this).attr('data-miq_sparkle_on') == 'true';

    if(typeof $(this).attr('data-miq_sparkle_off') != 'undefined')
      options.complete = $(this).attr('data-miq_sparkle_off') == 'true';

    if (options.callback) {
      options.done = function() {
        options.callback();
      };
    }

    miqObserveRequest(finalUrl, options);

    return true;
  }, 700, {leading: true, trailing: true}));
}

function miqAccordSelect(e) {
  if (ManageIQ.noCollapseEvent) { // implicitly return true when the noCollapseEvent is set
    return true;
  }
  if (!miqCheckForChanges()) {
    return false;
  }

  var url = '/' + $('body').data('controller') + '/accordion_select?id=' + $(e.target).attr('id');
  miqJqueryRequest(url, {beforeSend: true, complete: true});
  return true;
}

function miqInitBootstrapSwitch(element, url, options) {
  $("[name=" + element + "]").bootstrapSwitch();

  $('#' + element).on('switchChange.bootstrapSwitch', function(_event, state) {
    options =  typeof options !== 'undefined' ? options : {}
    options['no_encoding'] = true;

    var firstarg = ! _.contains(url, '?');
    miqObserveRequest(url + (firstarg ? '?' : '&') + element + '=' + state, options);

    return true;
  });
}

// Function to expand/collapse a pair of accordions
function miqAccordionSwap(_collapse, expand) {
  /*
   * Blocked by: https://github.com/twbs/bootstrap/issues/18418
   * TODO: uncomment this and delete below when the issue is fixed
   *
   * // Fire an one-time event after the collapse is done
   * $(collapse).one('hidden.bs.collapse', function () {
   *   $(expand).collapse('show');
   * });
   * // Fire an one-time event fater the expand is done
   * $(expand).one('shown.bs.collapse', function () {
   *   ManageIQ.noCollapseEvent = false;
   * })
   * ManageIQ.noCollapseEvent = true;
   * $(collapse).collapse('hide');
   *
   */
   ManageIQ.noCollapseEvent = true;
   $(expand).parent().find('.panel-heading a').trigger('click');
   ManageIQ.noCollapseEvent = false;
}

// This function is called in miqOnLoad
function miqInitToolbars() {
  $("#toolbar:not(.miq-toolbar-menu) button:not(.dropdown-toggle), "+
  "#toolbar:not(.miq-toolbar-menu) ul.dropdown-menu > li > a, "+
  "#toolbar:not(.miq-toolbar-menu) .toolbar-pf-view-selector > ul.list-inline > li > a"
  ).off('click');
  $("#toolbar:not(.miq-toolbar-menu) button:not(.dropdown-toggle), " +
  "#toolbar:not(.miq-toolbar-menu) ul.dropdown-menu > li > a, "+
  "#toolbar:not(.miq-toolbar-menu) .toolbar-pf-view-selector > ul.list-inline > li > a"
  ).click(miqToolbarOnClick);
}

// Function to run transactions when toolbar button is clicked
function miqToolbarOnClick(_e) {
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

  if (button.data("confirm-tb") && !button.data("popup")) {
    if (!confirm(button.data('confirm-tb'))) {
      return;
    }
  } else if (button.data("confirm-tb") && button.data("popup")) {
    // to open console in a new window
    if (confirm(button.data('confirm-tb'))) {
      if (button.data("window_url")) {
        window.open(button.data('window_url'));
      }
    }
    return;
  } else if (!button.data("confirm-tb") && button.data("popup")) {
    // to open readonly report in a new window, doesnt have confirm message
    if (button.data("window_url")) {
      window.open(button.data('window_url'));
    }
    return;
  }

  if (button.data("url")) {
    // See if a url is defined
    if (button.data('url').indexOf("/") === 0) {
      // If url starts with / it is non-ajax
      tb_url = "/" + ManageIQ.controller + button.data('url');
      if (ManageIQ.record.recordId !== null) {
        // remove last "/" if exist
        tb_url = tb_url.replace(/\/$/, "");
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
  } else if (button.data('function')) {
    // support data-function and data-function-data
    var fn = new Function("return " + button.data('function')); // eval - returns a function returning the right function
    fn().call(button, button.data('functionData'));
    return;
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
    if (typeof button.data('pressed') == "undefined" && button.data('click')) {
      tb_url += button.data('click').split("__").pop();
    } else {
      tb_url += button.data('pressed');
    }
  }

  if (button.data('prompt')) {
    tb_url = miqSupportCasePrompt(tb_url);
    if (!tb_url) {
      return false;
    }
  }

  // put url_parms into params var, if defined
  var params;
  if (button.data("url_parms")) {
    if (button.data('url_parms').match("_div$")) {
      if (ManageIQ.gridChecks.length) {
        params = "miq_grid_checks=" + ManageIQ.gridChecks.join(',');
      } else {
        params = miqSerializeForm(button.data('url_parms'));
      }
    } else {
      params = button.data('url_parms').split("?")[1];
    }
  }

  // TODO:
  // Checking for perf_reload button to not turn off spinning Q (will be done after charts are drawn).
  // Checking for Report download button to allow controller method to turn off spinner
  // Need to design this feature into the toolbar button support at a later time.
  var no_complete = _.includes([
      'perf_reload',
      'vm_perf_reload',
      'download_choice__render_report_csv',
      'download_choice__render_report_pdf',
      'download_choice__render_report_txt'
    ], button.attr('name')) || button.attr('name').match(/_console$/);

  var options = {
    beforeSend: true,
    complete: ! no_complete,
    data: params
  };

  miqJqueryRequest(tb_url, options);
  return false;
}

function miqSupportCasePrompt(tb_url) {
  var support_case = prompt(__('Enter Support Case:'), '');
  if (support_case === null) {
    return false;
  } else if (support_case.trim() == '') {
    alert(__('Support Case must be provided to collect logs'));
    return false;
  } else {
    tb_url = tb_url + '&support_case=' + encodeURIComponent(support_case);
    return tb_url;
  }
}

// Handle chart context menu clicks
function miqWidgetToolbarClick(_e) {
  var itemId = $(this).data('click');
  if (itemId == "reset") {
    if (confirm(__("Are you sure you want to reset this Dashboard's Widgets to the defaults?"))) {
      miqAjax("/dashboard/reset_widgets");
    }
  } else if (itemId == "add_widget") {
    return;
  } else {
    miqJqueryRequest("/dashboard/widget_add?widget=" + itemId, {beforeSend: true});
  }
}

function miqInitAccordions() {
  var height = $('#left_div').height() - $('#toolbar').outerHeight();
  var panel = $('#left_div .panel-heading').outerHeight();
  var count = $('#accordion:visible > .panel .panel-body').length;
  $('#accordion:visible > .panel .panel-body').each(function (_k, v) {
    if (window.matchMedia("(max-width: 768px)").matches) {
      $(v).css('max-height', '');
      $(v).css('overflow-y', 'none');
    } else {
      $(v).css('max-height', (height - count * panel) + 'px');
      $(v).css('overflow-y', 'auto');
    }
    $(v).css('overflow-x', 'hidden');
  });
}

// Function to resize the main content for best fit between the toolbar & footer
function miqInitMainContent() {
  var toolbar = $('#toolbar');
  var footer = $('#paging_div');
  var height = 0;
  if (footer.find('*:visible').length > 0) {
    height += footer.outerHeight();
  }
  if (toolbar.find("*:visible").length > 0) {
    height += toolbar.outerHeight();
  }

  $('#main-content').css('height', 'calc(100% - ' + height + 'px)')
}

function miqHideSearchClearButton() {
  // Hide the clear button if the search input is empty
  $(".search-pf .has-clear .clear").each(function() {
    if (!$(this).prev('.form-control').val()) {
      $(this).hide();
    }
  });
  // Show the clear button upon entering text in the search input
  $(".search-pf .has-clear .form-control").keyup(function () {
    var t = $(this);
    t.next('button').toggle(Boolean(t.val()));
  });
  // Upon clicking the clear button, empty the entered text and hide the clear button
  $(".search-pf .has-clear .clear").click(function () {
    $(this).prev('.form-control').val('').focus();
    $(this).hide();
  });
}

function toggle_expansion(link) {
  link = $(link);
  link.find("i").toggleClass("fa-angle-right fa-angle-down");
  link.closest('td').children(0).toggleClass("expanded");
}

function check_for_ellipsis() {
  var $element = $('.expand');
  $.each($element, function(_i, value) {
    var $val = $(value)
    var $c = $val.clone().css('overflow', 'initial').appendTo('body');
    if ( $c.width() > $val.width() && $val.parent().find('i.fa-angle-right').length == 0) {
      add_expanding_icon($val.parent())
    }
    $c.remove();
  });
};

function add_expanding_icon(element) {
  element.find('.pull-right').append("<a onclick='toggle_expansion(this)'> <i class='fa fa-angle-right'></i>");
}

function rbacGroupLoadTab(id) {
  var lazy = $('#' + id).hasClass('lazy');
  if (! lazy) {
    // already loaded
    return;
  }

  $('#' + id).removeClass('lazy');

  miqJqueryRequest('/ops/rbac_group_load_tab?tab_id=' + id, {
    beforeSend: true,
    complete: true,
  });
}

function chartData(type, data, data2) {
  if (type === undefined) {
    return;
  }

  if (_.isObject(data.miq)) {
    // set maximum count of x axis tick labels for C&U charts
    if (data.miq.performance_chart) {
      data.axis.x.tick.centered = true;
      data.axis.x.tick.culling = { max: 5 };
    }

    // small C&U charts have very limited height
    if (data.miq.flat_chart) {
      var max = _.max(getChartColumnDataValues(data.data.columns));
      data.axis.y.tick.values = [0, max];
    }

    if (data.miq.reporting_chart) {
      data.tooltip.format.name = function (_name, _ratio, id, _index) {
        return data.miq.name_table[id];
      };

      data.tooltip.format.title = function (x) {
        return data.miq.category_table[x];
      };
    }
  }

  // set formating function for tooltip and y tick labels
  if (_.isObject(data.axis) &&
      _.isObject(data.axis.y) &&
      _.isObject(data.axis.y.tick) &&
      _.isObject(data.axis.y.tick.format) &&
      data.axis.y.tick.format.function) {

    var format = data.axis.y.tick.format;
    var max = _.max(getChartColumnDataValues(data.data.columns));
    var min = _.min(getChartColumnDataValues(data.data.columns));
    var maxShowed = getChartFormatedValue(format, max);
    var minShowed = getChartFormatedValue(format, min);
    var changeFormat = true;

    var tmp = validateMinMax(min, max, minShowed, maxShowed);
    changeFormat = !tmp.invalid;
    min = tmp.min;

    if (changeFormat) {
      // if min and max are close, labels should be more precise
      var recalculated = recalculatePrecision(minShowed, maxShowed, format, min, max);
      format = recalculated.format;
    }
    data.axis.y.tick.format = ManageIQ.charts.formatters[format.function].c3(format.options);
    data.legend.item = {
      onclick: recalculateChartYAxisLabels
    }

    var titleFormat = _.cloneDeep(format);
    titleFormat.options.precision += 1;
    data.tooltip.format.value = function (value, _ratio, _id) {
      var format = ManageIQ.charts.formatters[titleFormat.function].c3(titleFormat.options);
      return format(value);
    }
  }

  var config = _.cloneDeep(ManageIQ.charts.c3config[type]);
  // some PatternFly default configs define contents function, but it breaks formatting
  if (_.isObject(config.tooltip)) {
    config.tooltip.contents = undefined;
  }
  // some PatternFly default configs define size of chart
  config.size = {};
  var ret = _.defaultsDeep({}, data, config, data2);
  return ret;
}

$(function () {
  $(window).on('resize', miqInitAccordions);
  $(window).on('resize', miqInitMainContent);
  $(window).on('resize', _.debounce(miqResetSizeTimer, 1000));

  check_for_ellipsis();
  $().setupVerticalNavigation(true);
});

function miqScrollToSelected(div_name) {
  var rowpos = $('tr.selected').position();
  if (rowpos) {
    $('#' + div_name).scrollTop(rowpos.top);
  }
}

function miqUncompressedId(id) {
  if (id.match(/r/)) {
    var splat = id.split('r');
    return sprintf("%s%012s", splat[0], splat[1]);
  }
  return id;
}

function queryParam(name) { return QS(window.location.href).get(name); }

function miqFormatNotification(text, bindings) {
  var str = __(text);
  _.each(bindings, function (value, key) {
    str = str.replace(new RegExp('%{' + key + '}', 'g'), value.text);
  });
  return str;
}
