class FileDepot < ApplicationRecord
  include NewWithTypeStiMixin
  include AuthenticationMixin
  include_concern 'ImportExport'
  include YAMLImportExportMixin

  has_many              :miq_schedules, :dependent => :nullify
  has_many              :miq_servers,   :dependent => :nullify, :foreign_key => :log_file_depot_id
  has_many              :log_files
  validates_presence_of :uri

  attr_accessor         :file

  def self.supported_depots
    @supported_depots ||= descendants.each_with_object({}) { |klass, hash| hash[klass.name] = Dictionary.gettext(klass.name, :type => :model, :notfound => :titleize, :translate => false) }.freeze
  end

  def self.supported_protocols
    @supported_protocols ||= subclasses.each_with_object({}) { |klass, hash| hash[klass.uri_prefix] = klass.name }.freeze
  end

  def self.depot_description_to_class(description)
    class_name = supported_depots.key(description)
    class_name.try(:constantize)
  end

  def self.requires_credentials?
    true
  end

  def requires_support_case?
    false
  end

  def upload_file(file)
    @file = file
  end

  def merged_uri(uri, _api_port)
    uri
  end
end
