class ManageIQ::Providers::CloudManager::AuthKeyPair < ::AuthPrivateKey
  include ReportableMixin
  acts_as_miq_taggable
  has_and_belongs_to_many :vms, :join_table => :key_pairs_vms, :foreign_key => :authentication_id

  include_concern 'Operations'

  def self.class_by_ems(ext_management_system)
    ext_management_system.class::AuthKeyPair
  end

  def self.create_key_pair(ext_management_system, options)
    klass = class_by_ems(ext_management_system)
    # TODO(maufart): add cloud_tenant to database table?
    created_key_pair = klass.raw_create_key_pair(ext_management_system, options)
    klass.create(
      :name        => created_key_pair.name,
      :fingerprint => created_key_pair.fingerprint,
      :resource    => ext_management_system
    )
  end

  def delete_key_pair
    raw_delete_key_pair
  end
end
