describe('GitImport', function() {
  describe('#retrieveDatastoreClickHandler', function() {
    var retrieveGitDatastoreCallback;

    beforeEach(function() {
      var html = '';
      html += '<form id="retrieve-git-datastore-form">';
      html += '  <input type="text" name="test" value="test" />';
      html += '  <button class="git-retrieve-datastore" />';
      html += '</form>';

      spyOn(window, 'miqSparkleOn');
      spyOn(window, 'clearMessages');

      spyOn($, 'post').and.callFake(function(url, data, callback) {
        retrieveGitDatastoreCallback = callback;
      });

      setFixtures(html);
      GitImport.retrieveDatastoreClickHandler();
    });

    it('turns on the spinner', function() {
      $('.git-retrieve-datastore').trigger('click');
      expect(window.miqSparkleOn).toHaveBeenCalled();
    });

    it('clears the messages', function() {
      $('.git-retrieve-datastore').trigger('click');
      expect(window.clearMessages).toHaveBeenCalled();
    });

    it('makes a post to retrieve the git datastore', function() {
      $('.git-retrieve-datastore').trigger('click');
      expect($.post).toHaveBeenCalledWith('retrieve_git_datastore', 'test=test', retrieveGitDatastoreCallback);

    });

    describe('#retrieveDatastoreClickHandler retrieveGitDatastoreCallback', function() {
      describe('when there are messages and the level is "error"', function() {
        beforeEach(function() {
          spyOn(window, 'showErrorMessage');
          spyOn(window, 'miqSparkleOff');

          retrieveGitDatastoreCallback('{"message": {"message": "the message", "level": "error"}}');
        });

        it('shows error messages', function() {
          expect(window.showErrorMessage).toHaveBeenCalledWith('the message');
        });

        it('turns off the sparkle', function() {
          expect(window.miqSparkleOff).toHaveBeenCalled();
        });
      });

      describe('when there are are no "error" level messages', function() {
        beforeEach(function() {
          spyOn(GitImport, 'pollForGitTaskCompletion');
          retrieveGitDatastoreCallback('{"message": {"message": "the message"}}');
        });

        it('polls for task completion', function() {
          expect(GitImport.pollForGitTaskCompletion).toHaveBeenCalledWith({message: {message: 'the message'}});
        });
      });
    });
  });

  describe('#pollForGitTaskCompletion', function() {
    var checkGitTaskCallback;

    beforeEach(function() {
      spyOn($, 'get').and.callFake(function(url, data, callback) {
        checkGitTaskCallback = callback;
      });
    });

    it('makes a get request to check_git_task', function() {
      GitImport.pollForGitTaskCompletion('the data');
      expect($.get).toHaveBeenCalledWith('check_git_task', 'the data', checkGitTaskCallback);
    });

    describe('#pollForGitTaskCompletion checkGitTaskCallback', function() {
      context('when data has a state', function() {
        beforeEach(function() {
          spyOn(window, 'setTimeout');
        });

        it('sets a timeout to call itself', function() {
          checkGitTaskCallback('{"state": "still doing stuff"}');
          expect(window.setTimeout).toHaveBeenCalledWith(GitImport.pollForGitTaskCompletion, 1500, 'the data');
        });
      });

      context('when the data does not have a state', function() {
        beforeEach(function() {
          spyOn(GitImport, 'gitTaskCompleted');
        });

        it('calls gitTaskCompleted with the parsed data', function() {
          checkGitTaskCallback('{"parsed": "data"}');
          expect(GitImport.gitTaskCompleted).toHaveBeenCalledWith({'parsed': 'data'});
        });
      });
    });
  });

  describe('#gitTaskCompleted', function() {
    var data = {
      git_repo_id: 123,
      git_branches: 'gitbranches',
      git_tags: 'gittags',
      message: 'the message'
    };

    beforeEach(function() {
      spyOn(parent, 'postMessage');
    });

    context('when data.success is true', function() {
      beforeEach(function() {
        data.success = true;
      });

      it('posts a message to the parent with all the git data', function() {
        GitImport.gitTaskCompleted(data);
        expect(parent.postMessage).toHaveBeenCalledWith({
          git_repo_id: 123,
          git_branches: 'gitbranches',
          git_tags: 'gittags',
          message: 'the message'
        }, '*');
      });
    });

    context('when data.success is false', function() {
      beforeEach(function() {
        data.success = false;
      });

      it('posts a message to the parent with only the message data', function() {
        GitImport.gitTaskCompleted(data);
        expect(parent.postMessage).toHaveBeenCalledWith({message: 'the message'}, '*');
      });
    });
  });
});
