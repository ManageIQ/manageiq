/* global miqJqueryRequest miqSetButtons miqSparkleOn */

(function($) {
  $.fn.miqGrid = function() {
    var table = $(this);
    var checkall = table.find('thead > tr > th > input.checkall');
    var checkboxes = table.find("tbody > tr > td > input[type='checkbox']");

    // table-selectable
    if (table.hasClass('table-clickable')) {
      var url = table.find('tbody').data('click-url');
      table.find('tbody > tr > td:not(.noclick)').click(function (e) {
        miqSparkleOn();
        var cid = $(this).parent().data('click-id');
        miqJqueryRequest(url + '?id=' + cid);
      });
    }

    // table-checkable
    if (table.hasClass('table-checkable')) {
      checkboxes.click(function (e) {
        var checked = $.map(checkboxes.filter(':checked'), function (cb) {
          return cb.value;
        });
        ManageIQ.gridChecks = checked;
        miqSetButtons(checked.length, 'center_tb');
        if (checked.length == checkboxes.length) {
          $('input.checkall').prop('checked', true);
        } else {
          $('input.checkall').prop('checked', false);
        }
      });

      // Handle the click on the "Check all" checkbox
      checkall.click(function (e) {
        var unchecked = checkboxes.filter(':not(:checked)');
        if (unchecked.length > 0) {
          unchecked.trigger('click');
        } else {
          checkboxes.trigger('click');
        }
      });
    }
  };
})(jQuery);
