describe TenancyMixin do
  let(:root_tenant) do
    Tenant.seed
  end

  let(:default_tenant) do
    root_tenant
    Tenant.default_tenant
  end

  describe "miq_group" do
    let(:user)         { FactoryGirl.create(:user, :userid => 'user', :miq_groups => [tenant_group]) }
    let(:tenant)       { FactoryGirl.build(:tenant, :parent => default_tenant) }
    let(:tenant_users) { FactoryGirl.create(:miq_user_role, :name => "tenant-users") }
    let(:tenant_group) { FactoryGirl.create(:miq_group, :miq_user_role => tenant_users, :tenant => tenant) }

    it "assigns owning group tenant" do
      vm = FactoryGirl.create(:vm_vmware, :miq_group => tenant_group)

      expect(vm.miq_group).to eql tenant_group
      expect(vm.tenant).to eql tenant
    end

    it "assigns current user tenant" do
      User.current_user = user
      vm = FactoryGirl.create(:vm_vmware)

      expect(vm.miq_group).to eql tenant_group
      expect(vm.tenant).to eql tenant
    end

    it "assigns parent EMS tenant" do
      tenant.save
      ems = FactoryGirl.create(:ems_vmware, :name => 'ems', :tenant => tenant)
      vm  = FactoryGirl.create(:vm_vmware, :ext_management_system => ems)

      expect(vm.miq_group).to eql tenant.default_miq_group
      expect(vm.tenant).to eql tenant
    end

    it "assigns root tenant" do
      root_tenant
      vm = FactoryGirl.create(:vm_vmware)

      expect(vm.miq_group).to eql root_tenant.default_miq_group
      expect(vm.tenant).to eql root_tenant
    end

    it "assigns the tenant group" do
      root_tenant
      tenant.save

      vm = FactoryGirl.create(:vm_vmware, :tenant => tenant)
      expect(vm.tenant).to eq(tenant)
      expect(vm.miq_group).to eq(tenant.default_miq_group)
    end
  end

  describe "assigning tenants without a miq_group" do
    let(:tenant)       { FactoryGirl.build(:tenant, :parent => default_tenant) }
    let(:tenant_users) { FactoryGirl.create(:miq_user_role, :name => "tenant-users") }
    let(:tenant_group) { FactoryGirl.create(:miq_group, :miq_user_role => tenant_users, :tenant => tenant) }

    it "assigns current user tenant" do
      User.current_user = FactoryGirl.create(:user, :userid => 'user', :miq_groups => [tenant_group])
      ems = FactoryGirl.create(:ext_management_system)

      expect(ems.tenant).to eql tenant
    end

    it "assigns root tenant" do
      root_tenant
      ems = FactoryGirl.create(:ext_management_system)

      expect(ems.tenant).to eql root_tenant
    end
  end
end
