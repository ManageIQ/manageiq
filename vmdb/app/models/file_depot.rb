class FileDepot < ActiveRecord::Base
  include NewWithTypeStiMixin
  include AuthenticationMixin
  belongs_to            :resource, :polymorphic => true
  has_many              :miq_servers, :foreign_key => :log_file_depot_id, :dependent => :nullify
  has_many              :log_files
  validates_presence_of :uri

  attr_accessor         :file

  def self.supported_depots
    @supported_depots ||= descendants.each_with_object({}) { |klass, hash| hash[klass.name] = Dictionary.gettext(klass.name, :type => :model, :notfound => :titleize) }.freeze
  end

  def self.requires_credentials?
    true
  end

  def requires_support_case?
    false
  end

  def depot_hash=(hsh = {})
    return if hsh == depot_hash
    update_authentication(:default => {:userid   => hsh[:username],
                                       :password => hsh[:password]})
    update_attribute(:uri, hsh[:uri])
    update_attribute(:name, hsh[:name])
  end

  def depot_hash
    {:username => authentication_userid,
     :uri      => uri,
     :password => authentication_password,
     :name     => name}
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
