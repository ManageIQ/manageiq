class ServiceResourceAttachment < ApplicationRecord
  include NewWithTypeStiMixin
  include ProviderObjectMixin
  include AsyncDeleteMixin
  include AvailabilityMixin
  include SupportsFeatureMixin
  include CustomActionsMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id
  belongs_to :storage_service, :inverse_of => :service_resource_attachments
  belongs_to :storage_resource, :inverse_of => :service_resource_attachments

  acts_as_miq_taggable

  def self.class_by_ems(ext_management_system)
    # TODO(lsmola) taken from OrchesTration stacks, correct approach should be to have a factory on ExtManagementSystem
    # side, that would return correct class for each provider
    ext_management_system && ext_management_system.class::physicalStorage
  end
end
