class FileDepot < ApplicationRecord
  #TODO: I believe this class and child classes are completely removable once log collection is deleted
  include NewWithTypeStiMixin
  include AuthenticationMixin
  include_concern 'ImportExport'
  include YAMLImportExportMixin

  has_many              :miq_schedules, :dependent => :nullify
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
