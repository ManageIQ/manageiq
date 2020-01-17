RSpec.describe Chargeback::ConsumptionWithRollups do
  let(:vm)          { FactoryBot.create(:vm_microsoft) }
  let(:consumption) { described_class.new(pluck_rollup([metric_rollup]), starting_date, starting_date + 1.day) }

  describe '#sub_metric_rollups' do
    let(:starting_date)        { Time.parse('2012-09-01 23:59:59Z').utc }
    let(:sub_metric)           { 'ssd' }
    let(:ssd_volume)           { FactoryBot.create(:cloud_volume_openstack, :volume_type => sub_metric) }
    let!(:state)         { FactoryBot.create(:vim_performance_state, :resource => vm, :state_data => nil, :timestamp => starting_date, :capture_interval => 3_600) }
    let!(:metric_rollup) { FactoryBot.create(:metric_rollup_vm_hr, :timestamp => starting_date + 1.hour, :resource => vm) }

    def pluck_rollup(metric_rollup_records)
      metric_rollup_records.pluck(*ChargeableField.cols_on_metric_rollup)
    end

    before do
      Timecop.travel(starting_date + 10.hours)
    end

    it "doesn't fail when there are no state data about disks" do
      expect(consumption.send(:values, 'derived_vm_allocated_disk_storage', sub_metric)).to match_array([0])
    end

    context 'vim performance state contains any state data for storage' do
      let(:volume_size) { 1_024 }

      before do
        state.capture
        state.allocated_disk_types = {sub_metric => volume_size}
        state.save
      end

      it 'returns values' do
        expect(consumption.send(:values, 'derived_vm_allocated_disk_storage', sub_metric)).to match_array([volume_size])
      end
    end

    context "vim performance state records don't exist" do
      before do
        VimPerformanceState.destroy_all
      end

      it 'all chargeback calculations return 0' do
        expect(consumption.send(:max, 'derived_vm_allocated_disk_storage', sub_metric)).to be_zero
        expect(consumption.send(:avg, 'derived_vm_allocated_disk_storage', sub_metric)).to be_zero
        expect(consumption.send(:sum, 'derived_vm_allocated_disk_storage', sub_metric)).to be_zero
      end
    end

    let(:ems) { FactoryBot.build(:ems_vmware) }

    context "Containers" do
      describe "#tag_list_with_prefix" do
        let(:tag) { FactoryBot.create(:tag, :name => "/managed/operations/analysis_failed") }
        let(:vm) { FactoryBot.create(:vm_vmware, :tags => [tag]) }
        let(:metric_rollup) { FactoryBot.create(:metric_rollup_vm_hr, :resource => vm, :tag_names => "environment/prod|environment/dev") }
        let(:consumption) { described_class.new(pluck_rollup([metric_rollup]), starting_date, starting_date + 1.day) }

        it 'returns array of tags' do
          expect(consumption.tag_list_with_prefix).to match_array(%w(vm/tag/managed/operations/analysis_failed vm/tag/managed/environment/prod vm/tag/managed/environment/dev))
        end
      end
    end

    context "Containers" do
      describe "#tag_list_with_prefix" do
        let(:timestamp) { Time.parse('2012-09-01 23:59:59Z').utc }
        let(:vim_performance_state) { FactoryBot.create(:vim_performance_state, :timestamp => timestamp, :image_tag_names => "environment/stage") }

        let(:image) { FactoryBot.create(:container_image, :ext_management_system => ems, :docker_labels => [label]) }
        let(:label) { FactoryBot.create(:custom_attribute, :name => "version/1.2/_label-1", :value => "test/1.0.0  rc_2", :section => 'docker_labels') }
        let(:project) { FactoryBot.create(:container_project, :name => "my project", :ext_management_system => ems) }
        let(:node) { FactoryBot.create(:container_node, :name => "node") }
        let(:group) { FactoryBot.create(:container_group, :ext_management_system => ems, :container_project => project, :container_node => node) }
        let(:container) { FactoryBot.create(:kubernetes_container, :container_group => group, :container_image => image, :vim_performance_states => [vim_performance_state]) }
        let(:metric_rollup_container) { FactoryBot.create(:metric_rollup_vm_hr, :timestamp => timestamp, :resource => container, :tag_names => "environment/cont|environment/cust") }
        let(:consumption) { described_class.new(pluck_rollup([metric_rollup_container]), starting_date, starting_date + 1.day) }

        it 'returns array of tags' do
          expect(consumption.tag_list_with_prefix).to match_array(%w(container_image/tag/managed/environment/cont container_image/tag/managed/environment/cust container_image/tag/managed/environment/stage container_image/label/managed/version/1.2/_label-1/test/1.0.0\ \ rc_2 container_image/label/managed/escaped:{version%2F1%2E2%2F%5Flabel%2D1}/escaped:{test%2F1%2E0%2E0%20%20rc%5F2}))
        end
      end
    end

    after do
      Timecop.return
    end
  end
end
