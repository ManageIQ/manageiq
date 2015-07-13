describe('import.js', function() {
  describe('#clearMessages', function() {
    beforeEach(function() {
      var html = '';
      html += '<div class="import-flash-message">';
      html += '  <div class="alert alert-success alert-danger alert-warning"></div>';
      html += '</div>';
      html += '<div class="icon-placeholder pficon pficon-ok pficon-layered"></div>';
      html += '<div id="error-octagon" class="pficon-error-octagon"></div>';
      html += '<div id="error-exclamation" class="pficon-error-exclamation"></div>';
      html += '<div id="warning-triangle" class="pficon-warning-triangle"></div>';
      html += '<div id="warning-exclamation" class="pficon-warning-exclamation"></div>';
      setFixtures(html);

      clearMessages();
    });

    it('removes alert classes', function() {
      expect($('.import-flash-message')).not.toHaveClass('alert-success');
      expect($('.import-flash-message')).not.toHaveClass('alert-danger');
      expect($('.import-flash-message')).not.toHaveClass('alert-warning');
    });

    it('removes pficon classes', function() {
      expect($('.icon-placeholder')).not.toHaveClass('pficon');
      expect($('.icon-placeholder')).not.toHaveClass('pficon-ok');
      expect($('.icon-placeholder')).not.toHaveClass('pficon-layered');
    });

    it('removes pficon-error-octagon class', function() {
      expect($('#error-octagon')).not.toHaveClass('pficon-error-octagon');
    });

    it('removes pficon-error-exclamation class', function() {
      expect($('#error-exclamation')).not.toHaveClass('pficon-error-exclamation');
    });

    it('removes pficon-warning-triangle class', function() {
      expect($('#warning-triangle')).not.toHaveClass('pficon-warning-triangle');
    });

    it('removes pficon-warning-exclamation class', function() {
      expect($('#warning-exclamation')).not.toHaveClass('pficon-warning-exclamation');
    });
  });
});
