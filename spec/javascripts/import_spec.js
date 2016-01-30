describe('import.js', function() {
  describe('ImportSetup', function() {
    describe('#respondToPostMessages', function() {
      var test = {
        callback: function(uploadId, message) { }
      };

      beforeEach(function() {
        spyOn(test, 'callback');
        spyOn(window, 'miqSparkleOff');
        spyOn(window, 'clearMessages');
        spyOn(window, 'showWarningMessage');
        spyOn(window, 'showErrorMessage');
      });

      context('when the import file upload id exists', function() {
        beforeEach(function() {
          var event = {
            data: {
              import_file_upload_id: 123,
              message: 'the message'
            }
          };

          ImportSetup.respondToPostMessages(event, test.callback);
        });

        it('turns the sparkle off', function() {
          expect(window.miqSparkleOff).toHaveBeenCalled();
        });

        it('clears the messages', function() {
          expect(window.clearMessages).toHaveBeenCalled();
        });

        it('triggers the callback', function() {
          expect(test.callback).toHaveBeenCalledWith(123, 'the message');
        });
      });

      context('when the import file upload id does not exist', function() {
        var event = {data: {import_file_upload_id: ''}};

        context('when the message level is warning', function() {
          beforeEach(function() {
            event.data.message = '{&quot;message&quot;:&quot;lol&quot;,&quot;level&quot;:&quot;warning&quot;}';
            ImportSetup.respondToPostMessages(event, test.callback);
          });

          it('turns the sparkle off', function() {
            expect(window.miqSparkleOff).toHaveBeenCalled();
          });

          it('clears the messages', function() {
            expect(window.clearMessages).toHaveBeenCalled();
          });

          it('displays a warning message with the message', function() {
            expect(window.showWarningMessage).toHaveBeenCalledWith('lol');
          });
        });

        context('when the message level is not warning', function() {
          beforeEach(function() {
            event.data.message = '{&quot;message&quot;:&quot;lol2&quot;,&quot;level&quot;:&quot;error&quot;}';
            ImportSetup.respondToPostMessages(event, test.callback);
          });

          it('turns the sparkle off', function() {
            expect(window.miqSparkleOff).toHaveBeenCalled();
          });

          it('clears the messages', function() {
            expect(window.clearMessages).toHaveBeenCalled();
          });

          it('displays an error message with the message', function() {
            expect(window.showErrorMessage).toHaveBeenCalledWith('lol2');
          });
        });
      });
    });
  });

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
