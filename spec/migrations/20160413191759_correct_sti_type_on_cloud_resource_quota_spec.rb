require_migration

describe CorrectStiTypeOnCloudResourceQuota do
  let(:cloud_resource_quota_stub) { migration_stub(:CloudResourceQuota) }
  let(:crq_entries) do
    [
      {:old => {:type => 'somethingelse'},
       :new => {:type => 'somethingelse'}},
      {:old => {:type => described_class::OLD_TYPE},
       :new => {:type => described_class::NEW_TYPE}},
      {:old => {:type => described_class::EVEN_OLDER_TYPE},
       :new => {:type => described_class::NEW_TYPE}},
    ]
  end

  migration_context :up do
    it 'migrates a series of representative rows' do
      crq_entries.each do |x|
        x[:up] = cloud_resource_quota_stub.create!(x[:old])
      end

      migrate

      crq_entries.each do |x|
        expect(x[:up].reload.type).to eq(x[:new][:type])
      end
    end
  end

  migration_context :down do
    it 'migrates a series of representative rows' do
      crq_entries.each do |x|
        x[:up] = cloud_resource_quota_stub.create!(x[:new])
      end

      migrate

      crq_entries.take(2).each do |x|
        expect(x[:up].reload.type).to eq(x[:old][:type])
      end
    end
  end
end
