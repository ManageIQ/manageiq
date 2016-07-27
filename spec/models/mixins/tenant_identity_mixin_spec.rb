describe TenantIdentityMixin do
  describe '#tenant_identity' do
    let(:admin)      { FactoryGirl.create(:user_with_group, :userid => "admin") }
    let(:tenant)     { FactoryGirl.create(:tenant) }
    let(:ems)        { FactoryGirl.create(:ext_management_system, :tenant => tenant) }
    let(:test_class) { :container_group }

    subject          { @test_instance.tenant_identity }
    before           { admin }

    it "has tenant from provider" do
      @test_instance = FactoryGirl.create(test_class, :ext_management_system => ems)

      expect(subject).to                eq(admin)
      expect(subject.current_group).to  eq(ems.tenant.default_miq_group)
      expect(subject.current_tenant).to eq(ems.tenant)
    end

    it "without a provider, has tenant from root tenant" do
      @test_instance = FactoryGirl.create(test_class)

      expect(subject).to                eq(admin)
      expect(subject.current_group).to  eq(Tenant.root_tenant.default_miq_group)
      expect(subject.current_tenant).to eq(Tenant.root_tenant)
    end
  end
end
