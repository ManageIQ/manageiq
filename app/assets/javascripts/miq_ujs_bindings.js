/* global dialogFieldRefresh miqCheckForChanges miqCheckMaxLength miqJqueryRequest miqMenuChangeRow miqObserveRequest miqSendDateRequest miqSendOneTrans miqSerializeForm miqSparkle miqSparkleOn */

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
    var submit = el.attr('data-submit');
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
  var attemptAutoRefreshTrigger = function(parms) {
    return function() {
      if (parms.auto_refresh === true) {
        dialogFieldRefresh.triggerAutoRefresh(parms);
      }
    };
  };

  var observeWithInterval = function(el, parms) {
    if (el.data('isObserved')) {
      return;
    }
    el.data('isObserved', true);

    var interval = parms.interval;
    var url = parms.url;
    var submit = parms.submit;

    el.observe_field(interval, function () {
      var oneTrans = this.getAttribute('data-miq_send_one_trans'); // Grab one trans URL, if present
      if (typeof submit != "undefined") {
        // If submit element passed in
        miqObserveRequest(url, {
          data: miqSerializeForm(submit),
          done: attemptAutoRefreshTrigger(parms),
        });
      } else if (oneTrans) {
        miqSendOneTrans(url, {
          observe: true,
          done: attemptAutoRefreshTrigger(parms),
        });
      } else {
        // tack on the id and value to the URL
        var data = {};
        data[el.attr('id')] = el.prop('value');

        miqObserveRequest(url, {
          done: attemptAutoRefreshTrigger(parms),
          data: data,
        });
      }
    });
  };

  var observeOnChange = function(el, parms) {
    // No interval passed, use event observer
    el.off('change');
    el.on('change', _.debounce(function() {
      var id = el.attr('id');
      var value = el.prop('multiple') ? el.val() : encodeURIComponent(el.prop('value'));

      miqObserveRequest(parms.url, {
        no_encoding: true,
        data: id + '=' + value,
        beforeSend: !! el.attr('data-miq_sparkle_on'),
        complete: !! el.attr('data-miq_sparkle_off'),
        done: attemptAutoRefreshTrigger(parms),
      });
    }, 700, {leading: true, trailing: true}));
  };

  $(document).on('focus', '[data-miq_observe]', function () {
    var el = $(this);
    var parms = $.parseJSON(el.attr('data-miq_observe'));

    if (typeof parms.interval == "undefined") {
      observeOnChange(el, parms);
    } else {
      observeWithInterval(el, parms);
    }
  });

  $(document).on('change', '[data-miq_observe_checkbox]', function (event) {
    var el = $(this);
    var parms = $.parseJSON(el.attr('data-miq_observe_checkbox'));
    var url = parms.url;

    var id = el.attr('id');
    var value = encodeURIComponent(el.prop('checked') ? el.val() : 'null');

    miqObserveRequest(url, {
      no_encoding: true,
      data: id + '=' + value,
      beforeSend: !! el.attr('data-miq_sparkle_on'),
      complete: !! el.attr('data-miq_sparkle_off'),
      done: attemptAutoRefreshTrigger(parms),
    });

    event.stopPropagation();
  });

  ManageIQ.observeDate = function(el) {
    miqSendDateRequest(el);
  };

  $(document).on('changeDate clearDate', '[data-miq_observe_date]', function() {
    ManageIQ.observeDate($(this));
  });

  // Run this last to be sure all other UJS bindings have been run in case the focus field is observed
  $('[data-miq_focus]').each(function(_index) {
    this.focus();
  });
});
