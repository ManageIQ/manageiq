/* global miqSparkleOn miqSparkleOff showErrorMessage clearMessages */

var GitImport = {
  retrieveDatastoreClickHandler: function() {
    $('.git-retrieve-datastore').click(function(event) {
      event.preventDefault();
      miqSparkleOn();
      clearMessages();

      $.post('retrieve_git_datastore', $('#retrieve-git-datastore-form').serialize(), function(data) {
        var parsedData = JSON.parse(data);
        var messages = parsedData.message;
        if (messages && messages.level === "error") {
          showErrorMessage(messages.message);
          miqSparkleOff();
        } else {
          GitImport.pollForGitTaskCompletion(parsedData);
        }
      });
    });
  },

  pollForGitTaskCompletion: function(gitData) {
    $.get('check_git_task', gitData, function(data) {
      var parsedData = JSON.parse(data);
      if (parsedData.state) {
        setTimeout(GitImport.pollForGitTaskCompletion, 1500, gitData);
      } else {
        GitImport.gitTaskCompleted(parsedData);
      }
    });
  },

  gitTaskCompleted: function(data) {
    if (data.success) {
      var postMessageData = {
        git_repo_id: data.git_repo_id,
        git_branches: data.git_branches,
        git_tags: data.git_tags,
        message: data.message
      };

      parent.postMessage(postMessageData, '*');
    } else {
      parent.postMessage({message: data.message}, '*');
    }
  },
};
