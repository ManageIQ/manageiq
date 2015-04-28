class FileDepot < ActiveRecord::Base
  include NewWithTypeStiMixin
  include AuthenticationMixin
  has_many              :miq_schedules, :dependent => :nullify
  has_many              :miq_servers,   :dependent => :nullify, :foreign_key => :log_file_depot_id
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
    deprecate_method(__method__, "attributes and authentications of the instance")
    return if hsh == depot_hash
    update_authentication(:default => {:userid   => hsh[:username],
                                       :password => hsh[:password]})
    update_attribute(:uri, hsh[:uri])
    update_attribute(:name, hsh[:name])
  end

  def depot_hash
    deprecate_method(__method__, "attributes and authentications of the instance")
    {:username => authentication_userid,
     :uri      => uri,
     :password => authentication_password,
     :name     => name}
  end

  def upload_file(file)
    @file = file
  end

  private

  def deprecate_method(method, instead)
    unless Rails.env.production?
      msg = "[DEPRECATION] #{method} method is deprecated.  Please use #{instead} instead.  At #{caller[1]}"
      $log.warn msg
      warn msg
    end
  end
end
