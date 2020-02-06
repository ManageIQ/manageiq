RSpec.describe ServiceOrchestration::ProvisionTagging do
  shared_examples_for 'service_orchestration VM tagging' do
    it 'assign tags' do
      expect(miq_request_task).to receive(:provision_priority).and_return(provision_priority)
      expect(Classification).to receive(:bulk_reassignment).with(
        :model      => 'Vm',
        :object_ids => [vm.id],
        :add_ids    => tag_ids
      )

      service.post_provision_configure
    end
  end

  describe '#apply_provisioning_tags' do
    before { expect(service).to receive(:assign_vms_owner) }

    let(:miq_request_task) { FactoryBot.create(:service_template_provision_task) }
    let(:vm) { FactoryBot.create(:vm) }
    let(:service) { FactoryBot.build(:service_orchestration, :miq_request_task => miq_request_task) }
    let(:dialog_tag_options) do
      { :dialog => {
        'Array::dialog_tag_0_env'     => 'Classification::1',
        'Array::dialog_tag_1_network' => 'Classification::11',
        'Array::dialog_tag_2_dept'    => 'Classification::21,Classification::22,Classification::23'
      }}
    end

    context 'without service dialog tag options' do
      it 'does not apply tags' do
        expect(Classification).to receive(:bulk_reassignment).never

        service.post_provision_configure
      end
    end

    context 'with a vm' do
      before { expect(service).to receive(:all_vms).and_return([vm]) }

      context 'with a single service and dialog tag options' do
        before { service[:options] = dialog_tag_options }

        context 'Calls Classification.bulk_reassignment with VM and tag IDs for provision_priority 0' do
          let(:provision_priority) { 0 }
          let(:tag_ids) { %w(1 11) }

          it_behaves_like 'service_orchestration VM tagging'
        end
      end

      context 'with a bundle service and dialog tag data' do
        before do
          parent_service[:options] = dialog_tag_options
          service.add_to_service(parent_service)
        end

        let(:parent_service) { FactoryBot.create(:service, :name => 'parent_service') }
        let(:service) { FactoryBot.build(:service_orchestration, :miq_request_task => miq_request_task) }

        context 'Calls Classification.bulk_reassignment with VM and tag IDs for provision_priority 0' do
          let(:provision_priority) { 0 }
          let(:tag_ids) { %w(1 11) }

          it_behaves_like 'service_orchestration VM tagging'
        end

        context 'Call Classification.bulk_reassignment with VM and tag IDs for provision_priority 1' do
          let(:provision_priority) { 1 }
          let(:tag_ids) { %w(1 21 22 23) }

          it_behaves_like 'service_orchestration VM tagging'
        end

        context 'Call Classification.bulk_reassignment with VM and tag IDs for provision_priority 2' do
          let(:provision_priority) { 2 }
          let(:tag_ids) { %w(1) }

          it_behaves_like 'service_orchestration VM tagging'
        end
      end
    end
  end
end
