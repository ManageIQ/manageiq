RSpec.describe ChargeableField, :type => :model do
  describe '#rate_name' do
    let(:source) { 'used' }
    let(:group) { 'cpu' }
    let(:field) { FactoryGirl.build(:chargeable_field, :source => source, :group => group) }
    subject { field.send :rate_name }
    it { is_expected.to eq("#{group}_#{source}") }
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

  describe '#seed' do
    let(:seed_hash) do
      [{:metric => 'cpu_usagemhz_rate_average', :description => 'Used CPU', :group => 'cpu', :source => 'used', :measure => 'Hz Units', :report_types => [:name => 'ChargebackVm']}]
    end

    before do
      ChargebackRateDetailMeasure.seed
      allow(described_class).to receive(:seed_data).and_return(seed_hash.deep_dup)
      described_class.seed
    end

    it 'seeds report types' do
      allow(described_class).to receive(:seed_data).and_return(seed_hash.deep_dup)
      expect(described_class.count).to eq(1)

      expect(described_class.find_by(:metric => "cpu_usagemhz_rate_average").report_types.count).to eq(1)
      expect(described_class.find_by(:metric => "cpu_usagemhz_rate_average").report_types.map(&:name)).to match_array(%w(ChargebackVm))
    end

    context 'new entry in yaml file after first seeding' do
      let(:seed_data_new_entry) do
        [{:metric => 'cpu_usagemhz_rate_average', :description => 'Used CPU', :group => 'cpu', :source => 'used', :measure => 'Hz Units', :report_types => [{:name => 'ChargebackVm'}, {:name => 'ChargebackContainerProject'}]},
         {:metric => 'v_derived_cpu_total_cores_used', :description => 'Used CPU Cores', :group => 'cpu_cores', :source => 'used', :report_types => [{:name => 'ChargebackContainerImage'}, {:name => 'ChargebackContainerProject'}]}]
      end

      it 'seeds report types' do
        allow(described_class).to receive(:seed_data_new_entry).and_return(seed_hash.deep_dup)

        described_class.seed
        expect(described_class.count).to eq(2)
        expect(described_class.find_by(:metric => "cpu_usagemhz_rate_average").report_types.count).to eq(2)
        expect(described_class.find_by(:metric => "cpu_usagemhz_rate_average").report_types.map(&:name)).to match_array(%w(ChargebackVm ChargebackContainerProject))

        expect(described_class.find_by(:metric => "v_derived_cpu_total_cores_used").report_types.count).to eq(2)
        expect(described_class.find_by(:metric => "v_derived_cpu_total_cores_used").report_types.map(&:name)).to match_array(%w(ChargebackContainerImage ChargebackContainerProject))
      end

      context 'remove entry from' do
        let(:seed_hash_remove) do
          [{:metric => 'cpu_usagemhz_rate_average', :description => 'Used CPU', :group => 'cpu', :source => 'used', :measure => 'Hz Units', :report_types => [:name => 'ChargebackContainerProject']},
           {:metric => 'v_derived_cpu_total_cores_used', :description => 'Used CPU Cores', :group => 'cpu_cores', :source => 'used', :report_types => [{:name => 'ChargebackContainerImage'}]}]
        end

        it 'seeds report types' do
          allow(described_class).to receive(:seed_data).and_return(seed_hash_remove.deep_dup)
          described_class.seed

          expect(described_class.count).to eq(2)
          expect(described_class.find_by(:metric => "cpu_usagemhz_rate_average").report_types.count).to eq(1)
          expect(described_class.find_by(:metric => "cpu_usagemhz_rate_average").report_types.map(&:name)).to match_array(%w(ChargebackContainerProject))

          expect(described_class.find_by(:metric => "v_derived_cpu_total_cores_used").report_types.count).to eq(1)
          expect(described_class.find_by(:metric => "v_derived_cpu_total_cores_used").report_types.map(&:name)).to match_array(%w(ChargebackContainerImage))
        end
      end
    end

    context 'changes report type' do
      let(:seed_hash_change) do
        [{:metric => 'cpu_usagemhz_rate_average', :description => 'Used CPU', :group => 'cpu', :source => 'used', :measure => 'Hz Units', :report_types => [:name => 'ChargebackContainerImage']}]
      end

      it 'seeds report types' do
        expect(described_class.count).to eq(1)
        expect(described_class.find_by(:metric => "cpu_usagemhz_rate_average").report_types.count).to eq(1)
        expect(described_class.find_by(:metric => "cpu_usagemhz_rate_average").report_types.map(&:name)).to match_array(%w(ChargebackVm))

        allow(described_class).to receive(:seed_data).and_return(seed_hash_change.deep_dup)
        described_class.seed

        expect(described_class.count).to eq(1)
        expect(described_class.find_by(:metric => "cpu_usagemhz_rate_average").report_types.count).to eq(1)
        expect(described_class.find_by(:metric => "cpu_usagemhz_rate_average").report_types.map(&:name)).to match_array(%w(ChargebackContainerImage))
      end
    end
  end
end
