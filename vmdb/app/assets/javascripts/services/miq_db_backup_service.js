miqAngularApplication.service('miqDBBackupService', function() {

  this.logProtocolNotSelected = function(model) {
    if(model.log_protocol == '')
      return true;
    else
      return false;
    };

  this.logProtocolSelected = function(model) {
    if(model.log_protocol != '')
      return true;
    else
      return false;
  };

  this.logProtocolChanged = function(model) {
    if(model.log_protocol == 'Network File System')
      model.uri_prefix = 'nfs';
    else
      model.uri_prefix = 'smb';
  };

  this.sambaBackup = function(model) {
    if(model.log_protocol == 'Samba')
      return true;
    else
      return false;
    };

  this.dbRequired = function(model, value) {
    return this.logProtocolSelected(model) &&
           (this.isModelValueNil(value));
  };

  this.sambaRequired = function(model, value) {
    return this.sambaBackup(model) &&
           (this.isModelValueNil(value));
  };

  this.isModelValueNil = function(value) {
    return value == null || value == '';
  };

});
