module MiqAeServiceTenantQuotaSpec
  describe MiqAeMethodService::MiqAeServiceTenantQuota do
    let(:settings) { {} }
    let(:tenant) { Tenant.create(:name => 'fred', :domain => 'a.b') }
    let(:cpu_quota) { TenantQuota.create(:name => "cpu_allocated", :unit => "int", :value => 2, :tenant => tenant) }
    let(:storage_quota) { TenantQuota.create(:name => "storage_allocated", :unit => "GB", :value => 160, :tenant => tenant) }

    let(:st_cpu_quota) { MiqAeMethodService::MiqAeServiceTenantQuota.find(cpu_quota.id) }
    let(:st_storage_quota) { MiqAeMethodService::MiqAeServiceTenantQuota.find(storage_quota.id) }

    before do
      stub_server_configuration(settings)
    end

    it "check max_cpu quota" do
      expect(st_cpu_quota.name).to eq('cpu_allocated')
      expect(st_cpu_quota.unit).to eq('int')
      expect(st_cpu_quota.value.to_i).to eq(2)
    end

    it "check storage quota" do
      expect(st_storage_quota.name).to eq('storage_allocated')
      expect(st_storage_quota.unit).to eq('GB')
      expect(st_storage_quota.value.to_i).to eq(160)
    end

    it "check tenant from quota" do
      expect(st_storage_quota.tenant.name).to eq('fred')
    end
  end
end
