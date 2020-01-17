RSpec.describe MetricRollup do
  describe '#parents_determining_rate' do
    let(:ems) { FactoryBot.build(:ems_vmware) }

    before do
      MiqRegion.seed
      MiqEnterprise.seed
    end

    context 'VmOrTemplate' do
      let(:ems_cluster) { FactoryBot.build(:ems_cluster, :ext_management_system => ems) }
      let(:storage) { FactoryBot.build(:storage_vmware) }
      let(:host) { FactoryBot.build(:host) }
      let(:vm) do
        FactoryBot.create(:vm_vmware, :name => 'test_vm', :ems_ref => 'ems_ref',
                           :ems_cluster => ems_cluster, :storage => storage, :host => host,
                           :ext_management_system => ems
                          )
      end

      subject { metric_rollup.parents_determining_rate }

      context 'metric_rollup record with parents not nil' do
        let(:metric_rollup) do
          FactoryBot.build(:metric_rollup_vm_hr,
                            :resource           => vm,
                            :parent_host        => host,
                            :parent_ems_cluster => ems_cluster,
                            :parent_ems         => ems,
                            :parent_storage     => storage,
                           )
        end

        let(:parents_from_rollup) do
          [
            metric_rollup.parent_host,
            metric_rollup.parent_ems_cluster,
            metric_rollup.parent_storage,
            metric_rollup.parent_ems,
            MiqEnterprise.my_enterprise
          ]
        end

        it { is_expected.to match_array(parents_from_rollup) }
      end

      context 'metric_rollup record with parents nil' do
        let(:metric_rollup) { FactoryBot.build(:metric_rollup_vm_hr, :resource => vm) }
        let(:parents_from_vm) do
          [
            vm.host,
            vm.ems_cluster,
            vm.storage,
            vm.ext_management_system,
            MiqEnterprise.my_enterprise
          ]
        end

        it { is_expected.to match_array(parents_from_vm) }
      end
    end
  end
end
