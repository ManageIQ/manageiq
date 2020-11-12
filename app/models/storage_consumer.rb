class StorageConsumer < ApplicationRecord
  include NewWithTypeStiMixin
  include ProviderObjectMixin
  include SupportsFeatureMixin
  include CustomActionsMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id
  belongs_to :physical_storage, :inverse_of => :storage_consumers

  has_many :addresses, :dependent => :destroy

  # https://github.com/ManageIQ/activerecord-virtual_attributes/blob/master/lib/active_record/virtual_attributes/virtual_total.rb
  # https://rubygems.org/gems/activerecord-virtual_attributes
  # https://github.com/ManageIQ/activerecord-virtual_attributes/pull/71/files
  # https://github.com/ManageIQ/manageiq/pull/16518/files
  # https://pemcg.gitbooks.io/mastering-automation-in-cloudforms-4-1-and-manage/content/peeping_under_the_hood/chapter.html
  virtual_total :v_total_addresses, :addresses

  def self.class_by_ems(ext_management_system)
    # TODO(lsmola) taken from Orchestration stacks, correct approach should be to have a factory on ExtManagementSystem
    # side, that would return correct class for each provider
    ext_management_system && ext_management_system.class::StorageConsumer
  end

end
