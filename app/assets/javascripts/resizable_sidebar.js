$.fn.resizableSidebar = function() {
  // Helper to increment the Y in the col-XX-YY by add
  var change_col = function(colstr, add) {
    var arr = colstr.split('-');
    var pos = arr.length - 1;
    arr[pos] = parseInt(arr[pos], 10) + add;
    return arr.join('-');
  }

  // Helper to get the current column width
  var get_col = function(colstr) {
    var arr = colstr.split('-');
    return parseInt(arr[arr.length - 1], 10);
  }

  var container = this;
  var columns = container.find('.resizable');
  if (columns.length == 2) { // only if there are 2 resizable columns
    var maindiv = columns.find('.resizer').parent();
    var sidebar = columns.not(maindiv);
    maindiv.find('.resizer-box .btn').click(function (event) {
      if ($(this).hasClass('btn-disabled')) return false;
      var left = $(this).hasClass('resize-left');
      var button = left ? $(this).next() : $(this);
      var ajax = 2; // the width of the sidebar which will be sent with an ajax request
      var left_class = [];
      var right_class = [];
      $.each(sidebar.attr('class').split(/\s+/), function (k, v) {
        if (left) {
          switch(v) {
            case 'col-md-5':
            case 'col-md-4':
            case 'col-md-3':
              ajax = get_col(v) - 1;
              left_class.push(change_col(v, -1));
              break;
            case 'col-md-2':
              ajax = 0;
              left_class.push('hidden-md');
              left_class.push('hidden-lg');
              left_class.push('col-md-0');
              break;
            case 'col-md-pull-7':
              button.removeClass('btn-disabled'); // re-enable the button when resizing to the left from max
            case 'col-md-pull-8':
            case 'col-md-pull-9':
              left_class.push(change_col(v, +1));
              break;
            case 'col-md-pull-10':
              break;
            default: // push all other classes without change
              left_class.push(v);
          }
        } else {
          switch(v) {
            case 'hidden-md':
            case 'hidden-lg':
              break; // when resizing to the right, remove hidden classes from sidebar
            case 'col-md-0':
              ajax = 2;
              left_class.push('col-md-2');
              left_class.push('col-md-pull-10');
              break;
            case 'col-md-4':
              button.addClass('btn-disabled'); // disable the right button if it reached it's limit
            case 'col-md-3':
            case 'col-md-2':
              ajax = get_col(v) + 1;
              left_class.push(change_col(v, +1));
              break;
            case 'col-md-pull-10':
            case 'col-md-pull-9':
            case 'col-md-pull-8':
              left_class.push(change_col(v, -1));
              break;
            default: // push all other classes without change
              left_class.push(v);
          }
        }
      });
      $.each(maindiv.attr('class').split(/\s+/), function (k, v) {
        if (left) {
          switch(v) {
            case 'col-md-10':
              right_class.push('col-md-12');
              break;
            case 'col-md-9':
            case 'col-md-8':
            case 'col-md-7':
              right_class.push(change_col(v, +1));
              break;
            case 'col-md-push-2':
              right_class.push('col-md-push-0')
              break;
            case 'col-md-push-3':
            case 'col-md-push-4':
            case 'col-md-push-5':
              right_class.push(change_col(v, -1));
              break;
            default: // push all other classes without change
              right_class.push(v);
          }
        } else {
          switch(v) {
            case 'col-md-12':
              right_class.push('col-md-10');
              break;
            case 'col-md-10':
            case 'col-md-9':
            case 'col-md-8':
              right_class.push(change_col(v, -1));
              break;
            case 'col-md-push-0':
              right_class.push('col-md-push-2');
              break;
            case 'col-md-push-2':
            case 'col-md-push-3':
            case 'col-md-push-4':
              right_class.push(change_col(v, +1));
              break;
            default: // push all other classes without change
              right_class.push(v);
          }
        }
      });
      // append the new classes to the divs
      sidebar.attr('class', left_class.join(' '));
      maindiv.attr('class', right_class.join(' '));
      // send the new width of the sidebar to the backend for future use
      miqJqueryRequest(miqPassFields('/dashboard/resize_layout', {sidebar: ajax, context: $('body').data('controller')}));
      miqOnResize();
    });
  }
};

$(function() {
  $('div.container-fluid.container-pf-nav-pf-vertical.container-pf-nav-pf-vertical-with-secondary.resizable-sidebar').resizableSidebar();
});
