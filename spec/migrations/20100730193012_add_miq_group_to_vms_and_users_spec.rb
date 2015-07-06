require "spec_helper"
require Rails.root.join("db/migrate/20100730193012_add_miq_group_to_vms_and_users.rb")


describe AddMiqGroupToVmsAndUsers do
  migration_context :up do
    let(:vm_stub)         { migration_stub(:Vm) }
    let(:user_stub)       { migration_stub(:User) }
    let(:miq_group_stub)  { migration_stub(:MiqGroup) }

    it "populates miq_group_id from group name in reserved column for users" do
      miq_group_name = "test-group"
      miq_group = miq_group_stub.create!(:description => miq_group_name)
      user = user_stub.create!(:reserved => {:ldap_group => miq_group_name})

      migrate

      user.reload.miq_group_id.should eq miq_group.id
    end

    it "populates miq_group_id from group name in reserved column for vms" do
      miq_group_name = "test-group"
      miq_group = miq_group_stub.create!(:description => miq_group_name)
      vm = vm_stub.create!(:reserved => {:owning_ldap_group => miq_group_name})

      migrate

      vm.reload.miq_group_id.should eq miq_group.id
    end
  end

  migration_context :down do
    let(:vm_stub)         { migration_stub(:Vm) }
    let(:user_stub)       { migration_stub(:User) }
    let(:miq_group_stub)  { migration_stub(:MiqGroup) }

    it "populates reserved as group name of miq_group_id column for users" do
      miq_group_name = "test-group"
      miq_group = miq_group_stub.create!(:description => miq_group_name)
      user = user_stub.create!(:miq_group_id => miq_group.id, :reserved => nil)

      migrate

      reserved = {:ldap_group => miq_group_name}
      user.reload.reserved.should eq reserved
    end

    it "populates reserved as group name of miq_group_id column for vms" do
      miq_group_name = "test-group"
      miq_group = miq_group_stub.create!(:description => miq_group_name)
      vm = vm_stub.create!(:miq_group_id => miq_group.id, :reserved => nil)

      migrate

      reserved = {:owning_ldap_group => miq_group_name}
      vm.reload.reserved.should eq reserved
    end
  end
end
