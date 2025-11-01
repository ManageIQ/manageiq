class FileDepot < ApplicationRecord
  include NewWithTypeStiMixin
  include AuthenticationMixin
  include ImportExport
  include YamlImportExportMixin

  has_many :miq_schedules, :dependent => :nullify

  validates_presence_of :uri

  def self.supported_depots
    descendants.each_with_object({}) { |klass, hash| hash[klass.name] = klass.display_name }
  end

  def self.supported_protocols
    @supported_protocols ||= subclasses.each_with_object({}) { |klass, hash| hash[klass.uri_prefix] = klass.name }.freeze
  end

  def self.requires_credentials?
    true
  end

  def merged_uri(uri, _api_port)
    uri
  end
end
