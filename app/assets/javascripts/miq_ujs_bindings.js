// MIQ unobtrusive javascript bindings run when document is fully loaded

$(document).ready(function () {
  // Bind call to prompt if leaving an active edit
  $(document).on('ajax:beforeSend', 'a[data-miq_check_for_changes]', function () {
    return miqCheckForChanges();
  });

  $(document).on('click', 'button[data-click_url]', function () {
    var el = $(this);
    var parms = $.parseJSON(el.attr('data-click_url'));
    var url = parms.url;
    var options = {};
    if (el.attr('data-miq_sparkle_on')) {
      options.beforeSend = true;
    }
    if (el.attr('data-miq_sparkle_off')) {
      options.complete = true;
    }
    submit = el.attr('data-submit');
    if (typeof submit != "undefined")
      miqJqueryRequest(url, {data: miqSerializeForm(submit)});
    else
      miqJqueryRequest(url, options);

    return false;
  });

  // bind button click to call JS function to send up grid data
  $(document).on('click', 'button[data-grid_submit]', function () {
    return miqMenuChangeRow($(this).attr('data-grid_submit'), $(this));
  });

  // Bind call to check/display text area max length on keyup
  $(document).on('keyup', 'textarea[data-miq_check_max_length]', function () {
    miqCheckMaxLength(this);
  });

  // Bind the MIQ spinning Q to configured links
  $(document).on('ajax:beforeSend', 'a[data-miq_sparkle_on]', function () {
    // Call to miqSparkleOn since miqSparkle(true) checks XHR count, which is 0 before send
    miqSparkleOn();
  });
  $(document).on('ajax:complete', 'a[data-miq_sparkle_off]', function () {
    miqSparkle(false);
  });

  // Handle data-submit - triggered by handleRemote from jquery-ujs
  $(document).on('ajax:before', 'a[data-submit]', function () {
    var form_id = $(this).data('submit');
    // because handleRemote will send the element's data-params as the POST body
    $(this).data('params', miqSerializeForm(form_id));
  });

  // Bind in the observe support. If interval is configured, use the observe_field function
  $(document).on('focus', '[data-miq_observe]', function () {
    var parms = $.parseJSON(this.getAttribute('data-miq_observe'));
    var interval = parms.interval;
    var url = parms.url;
    var submit = parms.submit;
    if (typeof interval == "undefined") {
      // No interval passed, use event observer
      var el = $(this);
      el.unbind('change')
      el.change(function() {
        if (parms.auto_refresh === true) {
          dialogFieldRefresh.triggerAutoRefresh(parms.field_id, parms.trigger);
        }
        var data = el.attr('id') + '=';
        if (el.prop('multiple')) {
          data += el.val();
        } else {
          data += encodeURIComponent(el.prop('value'));
        }

        var options = {
          no_encoding: true,
          data: data
        };
        if (el.attr('data-miq_sparkle_on')) {
          options.beforeSend = true;
        }
        if (el.attr('data-miq_sparkle_off')) {
          options.complete = true;
        }
        miqJqueryRequest(url, options);
      });
    } else {
      $(this).off(); // Use jQuery to turn off observe_field, prevents multi ajax transactions
      var el = $(this);
      el.observe_field(interval, function () {
        if (parms.auto_refresh === true) {
          dialogFieldRefresh.triggerAutoRefresh(parms.field_id, parms.trigger);
        }

        var oneTrans = this.getAttribute('data-miq_send_one_trans'); // Grab one trans URL, if present
        if (typeof submit != "undefined") {
          // If submit element passed in
          miqJqueryRequest(url, {data: miqSerializeForm(submit)});
        } else if (oneTrans) {
          miqSendOneTrans(url);
        } else {
          // tack on the id and value to the URL
          var urlstring = url + "?" + el.attr('id') + "=" + encodeURIComponent(el.prop('value'));
          miqJqueryRequest(urlstring, {no_encoding: true});
        }
      });
    }
  });

  $(document).on('click', '[data-miq_observe_checkbox]', function (event) {
    var el = $(this);
    var parms = $.parseJSON(el.attr('data-miq_observe_checkbox'));
    var url = parms.url;
    var options = {
      data: el.attr('id') + '=' + encodeURIComponent(el.prop('checked') ? el.val() : 'null')
    };

    if (parms.auto_refresh === true) {
      dialogFieldRefresh.triggerAutoRefresh(parms.field_id, parms.trigger);
    }

    if (el.attr('data-miq_sparkle_on')) {
      options.beforeSend = true;
    }
    if (el.attr('data-miq_sparkle_off')) {
      options.complete = true;
    }
    miqJqueryRequest(url, options);

    event.stopPropagation();
  });

  ManageIQ.observeDate = function(el) {
    miqSendDateRequest(el);
  };

  $(document).on('changeDate clearDate', '[data-miq_observe_date]', function() {
    ManageIQ.observeDate($(this));
  });

  // Run this last to be sure all other UJS bindings have been run in case the focus field is observed
  $('[data-miq_focus]').each(function (index) {
    this.focus();
  });
});
