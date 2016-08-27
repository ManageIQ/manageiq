/* global miqJqueryRequest miqSetButtons miqSparkleOn */

(function($) {
  $.fn.miqGrid = function() {
    var table = $(this);
    var checkall = table.find('thead > tr > th > input.checkall');
    var checkboxes = table.find("tbody > tr > td > input[type='checkbox']");

    // table-selectable
    if (table.hasClass('table-clickable')) {
      var url = table.find('tbody').data('click-url');
      table.find('tbody > tr > td:not(.noclick)').click(function (_e) {
        miqSparkleOn();
        var cid = $(this).parent().data('click-id');
        miqJqueryRequest(url + '?id=' + cid);
      });
    }

    // table-checkable
    if (table.hasClass('table-checkable')) {
      checkboxes.on('change', function (e) {
        var checked = $.map(checkboxes.filter(':checked'), function (cb) {
          return cb.value;
        });

        sendDataWithRx({rowSelect: e.delegateTarget});
        ManageIQ.gridChecks = checked;
        miqSetButtons(checked.length, 'center_tb');

        // if all the checkboxes were checked, make checkall checked too,
        // if some aren't, make it unchecked => no trigger here
        $('input.checkall')
          .prop('checked', checked.length == checkboxes.length);
      });

      // Handle the click on the "Check all" checkbox
      checkall.on('change', function (_e) {
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
