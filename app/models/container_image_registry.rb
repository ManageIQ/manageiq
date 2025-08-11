class ContainerImageRegistry < ApplicationRecord
  belongs_to :ext_management_system, :foreign_key => "ems_id"

  # Associated with images in the registry.
  has_many :container_images, :dependent => :nullify # images has a purger and are associated to containers so we can only disassociate them here
  has_many :containers, :through => :container_images
  has_many :container_groups, :through => :container_images

  # Associated with serving the registry itself - for openshift's internal
  # image registry. These will be empty for external registries.
  has_many :container_services # delete to be handled by refresh
  has_many :service_container_groups, :through => :container_services, :as => :container_groups

  acts_as_miq_taggable
  virtual_attribute :full_name, :string, :arel => (lambda do |t|
    t.grouping(Arel::Nodes::Case.new
                                .when(t[:port].eq(nil)).then(t[:host])
                                .when(t[:port].eq("")).then(t[:host])
                                .else(Arel::Nodes::NamedFunction.new('CONCAT', [t[:host], Arel.sql("':'"), t[:port]])))
  end)

  def full_name
    if has_attribute?("full_name")
      self["full_name"]
    else
      port.present? ? "#{host}:#{port}" : host
    end
  end
end
