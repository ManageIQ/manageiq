class ConfigurationManager < ActiveRecord::Base
  include NewWithTypeStiMixin
  include EmsRefresh::Manager
  include ReportableMixin

  acts_as_miq_taggable
  belongs_to :provider

  has_many :configured_systems,     :dependent => :destroy
  has_many :configuration_profiles, :dependent => :destroy

  delegate :zone, :my_zone, :zone_name, :to => :provider

  virtual_column :name,                :type => :string,      :uses => :provider
end
