RSpec.describe ChargeableField, :type => :model do
  describe '#rate_name' do
    let(:source) { 'used' }
    let(:group) { 'cpu' }
    let(:field) { FactoryBot.build(:chargeable_field, :source => source, :group => group) }
    subject { field.send :rate_name }
    it { is_expected.to eq("#{group}_#{source}") }
  end

  it "doesn't access database when unchanged model is saved" do
    m = FactoryBot.create(:chargeable_field)
    expect { m.valid? }.not_to make_database_queries
  end

  describe "#cols_on_metric_rollup" do
    before do
      ChargebackRateDetailMeasure.seed
      described_class.seed
    end

    it 'returns list of columns for main chargeback metric rollup query' do
      expected_columns = %w(
        id
        tag_names
        resource_id
        cpu_usage_rate_average
        cpu_usagemhz_rate_average
        derived_memory_available
        derived_memory_used
        derived_vm_allocated_disk_storage
        derived_vm_numvcpus
        derived_vm_used_disk_storage
        disk_usage_rate_average
        net_usage_rate_average
      )

      expect(described_class.cols_on_metric_rollup).to eq(expected_columns)
    end
  end
end
