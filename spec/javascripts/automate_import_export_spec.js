describe('Automate', function() {
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
      html += '<select class="git-branches">';
      html += '  <option value="1">Branch 1</option>';
      html += '  <option value="2" selected="selected">Branch 2</option>';
      html += '</select>';
      html += '<select class="git-tags">';
      html += '  <option value="1" selected="selected">Tag 1</option>';
      html += '  <option value="2">Tag 2</option>';
      html += '</select>';
      html += '<div class="git-branches"></div>';
      html += '<div class="git-tags"></div>';
      html += '';
      setFixtures(html);

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
    });

    describe('when the select.git-tags field changes', function() {
      beforeEach(function() {
        $('select.git-tags').val("2");
        $('select.git-tags').change();
      });

      it('copies the value of the git-tags select into the hidden field', function() {
        expect($('.git-branch-or-tag').val()).toEqual("2");
      });
    });
  });
});
