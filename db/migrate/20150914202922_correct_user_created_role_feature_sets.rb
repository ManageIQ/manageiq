class CorrectUserCreatedRoleFeatureSets < ActiveRecord::Migration
  class MiqUserRole < ActiveRecord::Base
    has_and_belongs_to_many :miq_product_features, :join_table => :miq_roles_features
  end
  class MiqProductFeature < ActiveRecord::Base
  end

  def up
    vm_cloud_explorer = MiqProductFeature.find_by_identifier("vm_cloud_explorer")
    vm_infra_explorer = MiqProductFeature.find_by_identifier("vm_infra_explorer")
    instances = MiqProductFeature.find_by_identifier("instance")
    images = MiqProductFeature.find_by_identifier("image")
    vms = MiqProductFeature.find_by_identifier("vm")
    templates = MiqProductFeature.find_by_identifier("miq_template")

    affected_user_roles.each do |user_role|
      if user_role.miq_product_features.include?(vm_cloud_explorer)
        user_role.miq_product_features << instances
        user_role.miq_product_features << images
      end

      if user_role.miq_product_features.include?(vm_infra_explorer)
        user_role.miq_product_features << vms
        user_role.miq_product_features << templates
      end

      user_role.save!
    end
  end

  def affected_user_roles
    MiqUserRole
      .includes(:miq_product_features)
      .where(:read_only => false, :miq_product_features => {:identifier => %w(vm_cloud_explorer vm_infra_explorer)})
  end
end
