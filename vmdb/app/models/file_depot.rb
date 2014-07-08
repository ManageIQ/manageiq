class FileDepot < ActiveRecord::Base
  DISPLAY_NAME = nil

  include NewWithTypeStiMixin
  include AuthenticationMixin
  belongs_to            :resource, :polymorphic => true
  has_many              :miq_servers, :foreign_key => :log_file_depot_id, :dependent => :nullify
  has_many              :log_files
  validates_presence_of :uri

  attr_accessor         :file

  def self.supported_depots
    descendants.each_with_object({}) { |klass, hash| hash[klass.name] = klass::DISPLAY_NAME }
  end

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

  def self.verify_depot_hash(hsh)
    return true unless MiqEnvironment::Command.is_appliance?

    # TODO: Move the logfile "depot" logic into remaining subclasses
    LogFile.verify_log_depot_settings(hsh)
  end

  def verify_credentials(_auth_type = nil)
    self.class.verify_depot_hash(self.depot_hash)
  end

  def upload_file(file)
    @file = file
  end
end
