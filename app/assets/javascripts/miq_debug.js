// CTRL+SHIFT+X stops the spinner
$(document).bind('keyup', 'ctrl+shift+x', miqSparkleOff);

// CTRL+SHIFT+Z checks for duplicate element ids
$(document).bind('keyup', 'ctrl+shift+z', function() {
  var ids = {};

  $('[id]').each(function(_i, e) {
    var id = $(e).attr('id');
    if (id in ids) {
      ids[id]++;
    } else {
      ids[id] = 1;
    }
  });

  _.keys(ids).forEach(function(id) {
    if (ids[id] <= 1)
      return;

    console.log('duplicate id', id, ids[id], $('[id="' + id + '"]'));
  });
  console.log('done');
});
