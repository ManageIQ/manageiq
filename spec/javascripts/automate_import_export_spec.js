describe('Automate', function() {
  describe('#setUpDefaultGitBranchOrTagValue', function() {
    beforeEach(function() {
      var html = '';
      html += '<input type="hidden" class="git-branch-or-tag"></input>';
      html += '<select class="git-branches selectpicker">';
      html += '  <option value="1">Branch 1</option>';
      html += '  <option value="2" selected="selected">Branch 2</option>';
      html += '</select>';
      html += '';
      setFixtures(html);

      miqInitSelectPicker();
    });

    it('ensures the selected value from the branches select tag is set on the hidden input', function() {
      expect($('.git-branch-or-tag').val()).toEqual('');
      Automate.setUpDefaultGitBranchOrTagValue();
      expect($('.git-branch-or-tag').val()).toEqual('2');
    });
  });

  describe('#selectDefaultBranch', function() {
    context('when "origin/master" does not exist as a branch', function() {
      beforeEach(function() {
        var html = '';
        html += '<input type="hidden" class="git-branch-or-tag"></input>';
        html += '<select class="git-branches selectpicker">';
        html += '  <option value="1">Branch 1</option>';
        html += '  <option value="2" selected="selected">Branch 2</option>';
        html += '</select>';
        html += '<button class="git-import-submit" disabled="true"/>';
        html += '';
        setFixtures(html);

        miqInitSelectPicker();
        Automate.selectDefaultBranch();
      });

      it('defaults to the first option', function() {
        expect($('select.git-branches').val()).toEqual('1');
      });

      it('sets the hidden input to the correct value', function() {
        expect($('.git-branch-or-tag').val()).toEqual('1');
      });

      it('sets the disabled property on the submit button to false', function() {
        expect($('.git-import-submit').prop('disabled')).toEqual(false);
      });
    });

    context('when "origin/master" does exist as a branch', function() {
      beforeEach(function() {
        var html = '';
        html += '<input type="hidden" class="git-branch-or-tag"></input>';
        html += '<select class="git-branches selectpicker">';
        html += '  <option value="1">Branch 1</option>';
        html += '  <option value="origin/master">origin/master</option>';
        html += '</select>';
        html += '<button class="git-import-submit" disabled="true"/>';
        html += '';
        setFixtures(html);

        miqInitSelectPicker();
        Automate.selectDefaultBranch();
      });

      it('selects "origin/master" as the value', function() {
        expect($('select.git-branches').val()).toEqual('origin/master');
      });

      it('sets the hidden input to the correct value', function() {
        expect($('.git-branch-or-tag').val()).toEqual('origin/master');
      });

      it('sets the disabled property on the submit button to false', function() {
        expect($('.git-import-submit').prop('disabled')).toEqual(false);
      });
    });
  });

  describe('#setUpGitRefreshClickHandlers', function() {
    beforeEach(function() {
      var html = '';
      html += '<select class="git-branch-or-tag-select">';
      html += '  <option value="Branch">Branch</option>';
      html += '  <option value="Tag">Tag</option>';
      html += '</select>';
      html += '<div class="git-branch-group"></div>';
      html += '<div class="git-tag-group"></div>';
      html += '<input type="hidden" class="git-branch-or-tag"></input>';
      html += '<select class="git-branches selectpicker">';
      html += '  <option value="1">Branch 1</option>';
      html += '  <option value="2" selected="selected">Branch 2</option>';
      html += '</select>';
      html += '<select class="git-tags selectpicker">';
      html += '  <option value="1" selected="selected">Tag 1</option>';
      html += '  <option value="2">Tag 2</option>';
      html += '</select>';
      html += '<button class="git-import-submit"/>';
      html += '';
      setFixtures(html);

      miqInitSelectPicker();

      Automate.setUpGitRefreshClickHandlers();
    });

    describe('when the git-branch-or-select field changes', function() {
      describe('when "Branch" is selected', function() {
        beforeEach(function() {
          $('.git-branch-or-tag-select').val("Branch");
          $('.git-branch-or-tag-select').change();
        });

        it('shows the git-branch-group', function() {
          expect($('.git-branch-group')).toBeVisible();
        });

        it('hides the git-tag-group', function() {
          expect($('.git-tag-group')).toBeHidden();
        });

        it('copies the value of the git-branches select into the hidden field', function() {
          expect($('.git-branch-or-tag').val()).toEqual("2");
        });

        it('toggles the submit button', function() {
          expect($('.git-import-submit').prop('disabled')).toEqual(false);
        });
      });

      describe('when "Tag" is selected', function() {
        beforeEach(function() {
          $('.git-branch-or-tag-select').val("Tag");
          $('.git-branch-or-tag-select').change();
        });

        it('hides the git-branch-group', function() {
          expect($('.git-branch-group')).toBeHidden();
        });

        it('shows the git-tag-group', function() {
          expect($('.git-tag-group')).toBeVisible();
        });

        it('copies the value of the git-tag select into the hidden field', function() {
          expect($('.git-branch-or-tag').val()).toEqual("1");
        });

        it('toggles the submit button', function() {
          expect($('.git-import-submit').prop('disabled')).toEqual(false);
        });
      });
    });

    describe('when the select.git-branches field changes', function() {
      beforeEach(function() {
        $('select.git-branches').val("1");
        $('select.git-branches').change();
      });

      it('copies the value of the git-branches select into the hidden field', function() {
        expect($('.git-branch-or-tag').val()).toEqual("1");
      });

      it('toggles the submit button', function() {
        expect($('.git-import-submit').prop('disabled')).toEqual(false);
      });
    });

    describe('when the select.git-tags field changes', function() {
      beforeEach(function() {
        $('select.git-tags').val("2");
        $('select.git-tags').change();
      });

      it('copies the value of the git-tags select into the hidden field', function() {
        expect($('.git-branch-or-tag').val()).toEqual("2");
      });

      it('toggles the submit button', function() {
        expect($('.git-import-submit').prop('disabled')).toEqual(false);
      });
    });
  });
});
