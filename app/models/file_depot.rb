class FileDepot < ApplicationRecord
  include NewWithTypeStiMixin
  include AuthenticationMixin
  include ImportExport
  include YamlImportExportMixin

  has_many              :miq_schedules, :dependent => :nullify
  has_many              :log_files
  validates_presence_of :uri

  attr_accessor         :file

  def self.supported_depots
    descendants.each_with_object({}) { |klass, hash| hash[klass.name] = klass.display_name }
  end

  def self.supported_protocols
    @supported_protocols ||= subclasses.each_with_object({}) { |klass, hash| hash[klass.uri_prefix] = klass.name }.freeze
  end

  def self.requires_credentials?
    true
  end

  def upload_file(file)
    @file = file
  end

  def merged_uri(uri, _api_port)
    uri
  end
end
