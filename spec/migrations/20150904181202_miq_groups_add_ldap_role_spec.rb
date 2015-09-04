require "spec_helper"
require_migration

describe MiqGroupsAddLdapRole do
  let(:miq_user_role_stub) { migration_stub(:MiqUserRole) }
  let(:miq_group_stub)     { migration_stub(:MiqGroup) }

  it "migrates ldap groups" do
    role = miq_user_role_stub.create!("EvmRole-my_group")
    unchanged_group = miq_group_stub.create!(:description => "EvmGroup-super_administrator", :group_type => "abc")
    changed_group = miq_group_stub.create!(:description => "EvmGroup-my_group", :group_type => "ldap")

    migrate
    changed_group.reload

    expect(unchanged_group.reload.group_type).to eq("abc")
    expect(changed_group.group_type).to eq("system")
    expect(changed_group.role).to eq(role)
  end
end
