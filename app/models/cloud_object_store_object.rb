class CloudObjectStoreObject < ApplicationRecord
  include CloudTenancyMixin
  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ExtManagementSystem"
  belongs_to :cloud_tenant
  belongs_to :cloud_object_store_container

  acts_as_miq_taggable

  include ProviderObjectMixin
  include NewWithTypeStiMixin
  include ProcessTasksMixin
  include SupportsFeatureMixin

  include_concern 'Operations'

  alias_attribute :name, :key

  supports_not :delete, :reason => N_("Delete operation is not supported.")

  def disconnect_inv
    # This is for bypassing a weird Rails behaviour. If we do a ems.cloud_object_store_objects.delete(objects) and a
    # relation in the ems is missing a :dependent => :destroy on :cloud_object_store_objects relation, it does not
    # delete any records. The :dependent => :destroy was removed by https://github.com/ManageIQ/manageiq/pull/14009
    #
    # Method disconnect_inv is called on each record separately, so it will destroy records as expected.
    # The fact that refresh deletes a non existent records from our DB is tested by AWS S3 stubbed specs.
    #
    # TODO(lsmola) investigate rails weird behavior, write a reproducer and delete this when fixed. Unless this is an
    # expected behaviour.
    destroy
  end
end
