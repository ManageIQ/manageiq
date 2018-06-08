describe MetricRollup do
  describe '#parents_determining_rate' do
    let(:ems) { FactoryGirl.build(:ems_vmware) }

    before do
      MiqRegion.seed
      MiqEnterprise.seed
    end

    context 'VmOrTemplate' do
      let(:ems_cluster) { FactoryGirl.build(:ems_cluster, :ext_management_system => ems) }
      let(:storage) { FactoryGirl.build(:storage_target_vmware) }
      let(:host) { FactoryGirl.build(:host) }
      let(:vm) do
        FactoryGirl.create(:vm_vmware, :name => 'test_vm', :ems_ref => 'ems_ref',
                           :ems_cluster => ems_cluster, :storage => storage, :host => host,
                           :ext_management_system => ems
                          )
      end

      subject { metric_rollup.parents_determining_rate }

      context 'metric_rollup record with parents not nil' do
        let(:metric_rollup) do
          FactoryGirl.build(:metric_rollup_vm_hr,
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
        let(:metric_rollup) { FactoryGirl.build(:metric_rollup_vm_hr, :resource => vm) }
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

      describe "#tag_list_with_prefix" do
        let(:tag) { FactoryGirl.create(:tag, :name => "/managed/operations/analysis_failed") }
        let(:vm) { FactoryGirl.create(:vm_vmware, :tags => [tag]) }
        let(:metric_rollup) { FactoryGirl.create(:metric_rollup_vm_hr, :resource => vm, :tag_names => "environment/prod|environment/dev") }

        it 'returns array of tags' do
          expect(metric_rollup.tag_list_with_prefix).to match_array(%w(vm/tag/managed/operations/analysis_failed vm/tag/managed/environment/prod vm/tag/managed/environment/dev))
        end
      end
    end

    context "with Containers" do
      describe "#tag_list_with_prefix" do
        let(:timestamp) { Time.parse('2012-09-01 23:59:59Z').utc }
        let(:vim_performance_state) { FactoryGirl.create(:vim_performance_state, :timestamp => timestamp, :image_tag_names => "environment/stage") }

        let(:image) { FactoryGirl.create(:container_image, :ext_management_system => ems, :docker_labels => [label]) }
        let(:label) { FactoryGirl.create(:custom_attribute, :name => "version/1.2/_label-1", :value => "test/1.0.0  rc_2", :section => 'docker_labels') }
        let(:project) { FactoryGirl.create(:container_project, :name => "my project", :ext_management_system => ems) }
        let(:node) { FactoryGirl.create(:container_node, :name => "node") }
        let(:group) { FactoryGirl.create(:container_group, :ext_management_system => ems, :container_project => project, :container_node => node) }
        let(:container) { FactoryGirl.create(:kubernetes_container, :container_group => group, :container_image => image, :vim_performance_states => [vim_performance_state]) }
        let(:metric_rollup_container) { FactoryGirl.create(:metric_rollup_vm_hr, :timestamp => timestamp, :resource => container, :tag_names => "environment/cont|environment/cust") }

        it 'returns array of tags' do
          expect(metric_rollup_container.tag_list_with_prefix).to match_array(%w(container_image/tag/managed/environment/cont container_image/tag/managed/environment/cust container_image/tag/managed/environment/stage container_image/label/managed/version/1.2/_label-1/test/1.0.0\ \ rc_2 container_image/label/managed/escaped:{version%2F1%2E2%2F%5Flabel%2D1}/escaped:{test%2F1%2E0%2E0%20%20rc%5F2}))
        end
      end
    end
  end
end
