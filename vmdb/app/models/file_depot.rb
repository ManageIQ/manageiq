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

  def self.supported_protocols
    @supported_depots ||= subclasses.each_with_object({}) { |klass, hash| hash[klass.uri_prefix] = klass.name }.freeze
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

  def upload_file(file)
    @file = file
  end
end

# load all plugins
Dir.glob(File.join(File.dirname(__FILE__), "file_depot_*.rb")).sort.each { |f| require_dependency f rescue true }
