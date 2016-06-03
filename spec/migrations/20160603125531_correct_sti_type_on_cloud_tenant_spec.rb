require_migration

describe CorrectStiTypeOnCloudTenant do
  let(:cloud_tenant_stub) { migration_stub(:CloudTenant) }
  let(:cloud_tenant_entries) do
    [
      {:old => {:type => nil},
       :new => {:type => described_class::NEW_TYPE}}
    ]
  end

  migration_context :up do
    it 'migrates a series of representative rows' do
      cloud_tenant_entries.each do |x|
        x[:up] = cloud_tenant_stub.create!(x[:old])
      end

      migrate

      cloud_tenant_entries.each do |x|
        expect(x[:up].reload.type).to eq(x[:new][:type])
      end
    end
  end

  migration_context :down do
    it 'migrates a series of representative rows' do
      cloud_tenant_entries.each do |x|
        x[:up] = cloud_tenant_stub.create!(x[:new])
      end

      migrate

      cloud_tenant_entries.take(2).each do |x|
        expect(x[:up].reload.type).to eq(x[:old][:type])
      end
    end
  end
end
