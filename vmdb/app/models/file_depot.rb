class FileDepot < ActiveRecord::Base
  include AuthenticationMixin
  belongs_to            :resource, :polymorphic => true
  has_many              :log_files
  validate              :validate_credentials
  validates_presence_of :uri

  attr_accessor         :file

  SUPPORTED_DEPOTS = {
    'smb' => 'Samba',
    'nfs' => 'Network File System'}.freeze

  def depot_hash=(hsh = {})
    return if hsh == self.depot_hash
    self.update_authentication( {:default => {:userid => hsh[:username], :password => hsh[:password]} } )
    self.update_attribute(:uri, hsh[:uri])
  end

  def depot_hash
    { :username => self.authentication_userid,
      :uri      => self.uri,
      :password => self.authentication_password
    }
  end

  #TODO: Move the depot logic out of LogFile and add it here
  def requires_credentials?
    LogFile.requires_credentials?(LogFile.get_post_method(:uri => self.uri))
  end

  def validate_credentials
    errors.add(:file_depot, "is missing credentials") if requires_credentials? && authentication_invalid?
  end

  def self.verify_depot_hash(hsh)
    return true unless MiqEnvironment::Command.is_appliance?

    # TODO: Move the logfile "depot" logic into this model
    LogFile.verify_log_depot_settings(hsh)
  end

  def verify_credentials(auth_type=nil)
    self.class.verify_depot_hash(self.depot_hash)
  end

  def upload_file(file)
    @file = file
  end
end
