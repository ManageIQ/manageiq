describe('resizable-sidebar.js', function () {
  beforeEach(function () {
    var html = ''
    html += '<div class="container-fluid resizable-sidebar">'
    html += '  <div class="row">'
    html += '    <div class="col-md-10 col-md-push-2 resizable" id="right">'
    html += '      <div class="resizer hidden-xs">'
    html += '        <div class="resizer-box">'
    html += '          <div class="btn-group">'
    html += '            <div class="btn btn-default resize-left">'
    html += '              <span class="fa fa-angle-left"></span>'
    html += '            </div>'
    html += '            <div class="btn btn-default resize-right">'
    html += '              <span class="fa fa-angle-right"></span>'
    html += '            </div>'
    html += '          </div>'
    html += '        </div>'
    html += '      </div>'
    html += '    </div>'
    html += '    <div class="col-md-2 col-md-pull-10 resizable" id="left">'
    html += '    </div>'
    html += '  </div>'
    html += '</div>'

    setFixtures(html);
    $('div.container-fluid.resizable-sidebar').resizableSidebar();
    spyOn($, 'ajax'); // we're not testing the backend
  });

  it('hide sidebar', function () {
    $('.resize-left').click();

    expect($('#left')).not.toHaveClass('col-md-2');
    expect($('#left')).not.toHaveClass('col-md-pull-10');
    expect($('#left')).toHaveClass('hidden-lg');
    expect($('#left')).toHaveClass('hidden-md');

    expect($('#right')).not.toHaveClass('col-md-10');
    expect($('#right')).not.toHaveClass('col-md-push-2');
    expect($('#right')).toHaveClass('col-md-12');
    expect($('#right')).toHaveClass('col-md-push-0');
  });

  it('show sidebar', function () {
    $('.resize-left').click();
    $('.resize-right').click();

    expect($('#left')).not.toHaveClass('hidden-md');
    expect($('#left')).not.toHaveClass('hidden-lg');
    expect($('#left')).toHaveClass('col-md-2');
    expect($('#left')).toHaveClass('col-md-pull-10');

    expect($('#right')).not.toHaveClass('col-md-12');
    expect($('#right')).not.toHaveClass('col-md-push-0');
    expect($('#right')).toHaveClass('col-md-10');
    expect($('#right')).toHaveClass('col-md-push-2');
  });

  it('broaden sidebar', function () {
    for (var i=2; i<=5; i++) {
      expect($('#left')).not.toHaveClass('col-md-' + (i-1));
      expect($('#left')).not.toHaveClass('col-md-pull-' + (11-i));
      expect($('#left')).toHaveClass('col-md-' + i);
      expect($('#left')).toHaveClass('col-md-pull-' + (12-i));

      expect($('#right')).not.toHaveClass('col-md-' + (13-i));
      expect($('#right')).not.toHaveClass('col-md-push-' + (i+1));
      expect($('#right')).toHaveClass('col-md-' + (12-i));
      expect($('#right')).toHaveClass('col-md-push-' + i);

      $('.resize-right').click();
    }
  });

  it('narrow sidebar', function () {
    for (var i=5; i<=2; i--) {
      expect($('#left')).not.toHaveClass('col-md-' + (i+1));
      expect($('#left')).not.toHaveClass('col-md-pull-' + (13-i));
      expect($('#left')).toHaveClass('col-md-' + i);
      expect($('#left')).toHaveClass('col-md-pull-' + (12-i));

      expect($('#right')).not.toHaveClass('col-md-' + (11-i));
      expect($('#right')).not.toHaveClass('col-md-push-' + (i-1));
      expect($('#right')).toHaveClass('col-md-' + (12-i));
      expect($('#right')).toHaveClass('col-md-push-' + i);

      $('.resize-right').click();
    }
  });

  it('extend sidebar limit', function () {
    for (var i=0; i<5; i++) {
      $('.resize-right').click();
    }
    expect($('#left')).toHaveClass('col-md-5');
    expect($('#left')).toHaveClass('col-md-pull-7');
    expect($('#right')).toHaveClass('col-md-7');
    expect($('#right')).toHaveClass('col-md-push-5');
  });

});