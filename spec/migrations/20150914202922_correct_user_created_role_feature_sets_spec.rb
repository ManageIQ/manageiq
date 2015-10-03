require "spec_helper"
require_migration

RSpec.describe CorrectUserCreatedRoleFeatureSets do
  migration_context :up do
    let(:user_role_stub) { migration_stub(:MiqUserRole) }
    let(:product_feature_stub) { migration_stub(:MiqProductFeature) }

    it "adds 'instance' and 'image' to user roles product features with 'vm_cloud_explorer'" do
      instances = product_feature_stub.create!(
        :name         => "Instance Access Rules",
        :description  => "Access Rules for Instances",
        :feature_type => "node",
        :identifier   => "instance"
      )
      images = product_feature_stub.create!(
        :name         => "Image Access Rules",
        :description  => "Access Rules for Images",
        :feature_type => "node",
        :identifier   => "image"
      )
      vm_cloud_explorer = product_feature_stub.create!(
        :name         => "Instances",
        :description  => "Instance Views",
        :feature_type => "node",
        :identifier   => "vm_cloud_explorer"
      )
      user_role = user_role_stub.create!(:miq_product_features => [vm_cloud_explorer], :read_only => false)

      expect(user_role.miq_product_features).not_to include(instances)
      expect(user_role.miq_product_features).not_to include(images)

      migrate
      user_role.reload

      expect(user_role.miq_product_features).to include(instances)
      expect(user_role.miq_product_features).to include(images)
    end

    it "adds 'vm' and 'miq_template' to user roles product features with 'vm_infra_explorer'" do
      vms = product_feature_stub.create!(
        :name         => "VM Access Rules",
        :description  => "Access Rules for Virtual Machines",
        :feature_type => "node",
        :identifier   => "vm"
      )
      templates = product_feature_stub.create!(
        :name         => "Template Access Rules",
        :description  => "Access Rules for Templates",
        :feature_type => "node",
        :identifier   => "miq_template"
      )
      vm_infra_explorer = product_feature_stub.create!(
        :name         => "Virtual Machines",
        :description  => "Virtual Machine Views",
        :feature_type => "node",
        :identifier   => "vm_infra_explorer"
      )
      user_role = user_role_stub.create!(:miq_product_features => [vm_infra_explorer], :read_only => false)

      expect(user_role.miq_product_features).not_to include(vms)
      expect(user_role.miq_product_features).not_to include(templates)

      migrate
      user_role.reload

      expect(user_role.miq_product_features).to include(vms)
      expect(user_role.miq_product_features).to include(templates)
    end

    it "leaves user roles with neither feature set alone" do
      product_feature_stub.create!(
        :name         => "VM Access Rules",
        :description  => "Access Rules for Virtual Machines",
        :feature_type => "node",
        :identifier   => "vm"
      )
      product_feature_stub.create!(
        :name         => "Template Access Rules",
        :description  => "Access Rules for Templates",
        :feature_type => "node",
        :identifier   => "miq_template"
      )
      product_feature_stub.create!(
        :name         => "Virtual Machines",
        :description  => "Virtual Machine Views",
        :feature_type => "node",
        :identifier   => "vm_infra_explorer"
      )
      user_role = user_role_stub.create!(:miq_product_features => [], :read_only => false)

      expect { migrate }.not_to change { user_role.reload.miq_product_features }
    end

    it "leaves read only user roles alone" do
      product_feature_stub.create!(
        :name         => "VM Access Rules",
        :description  => "Access Rules for Virtual Machines",
        :feature_type => "node",
        :identifier   => "vm"
      )
      product_feature_stub.create!(
        :name         => "Template Access Rules",
        :description  => "Access Rules for Templates",
        :feature_type => "node",
        :identifier   => "miq_template"
      )
      vm_infra_explorer = product_feature_stub.create!(
        :name         => "Virtual Machines",
        :description  => "Virtual Machine Views",
        :feature_type => "node",
        :identifier   => "vm_infra_explorer"
      )
      user_role = user_role_stub.create!(:miq_product_features => [vm_infra_explorer], :read_only => true)

      expect { migrate }.not_to change { user_role.reload.miq_product_features }
    end
  end
end
