describe ApplicationHelper::Button::VmSnapshotAdd do
  let(:view_context) { setup_view_context_with_sandbox({}) }
  let(:zone) { EvmSpecHelper.local_miq_server(:is_master => true).zone }
  let(:ems) { FactoryGirl.create(:ems_vmware, :zone => zone, :name => 'Test EMS') }
  let(:host) { FactoryGirl.create(:host) }
  let(:record) { FactoryGirl.create(:vm_vmware, :ems_id => ems.id, :host_id => host.id) }
  let(:active) { true }
  let(:button) { described_class.new(view_context, {}, {'record' => record, 'active' => active}, {}) }

  describe '#calculate_properties' do
    before { button.calculate_properties }
    context 'when creating snapshots is available' do
      let(:current) { 1 }
      let(:record) do
        record = FactoryGirl.create(:vm_vmware, :ems_id => ems.id, :host_id => host.id)
        record.snapshots = [FactoryGirl.create(:snapshot,
                                               :create_time       => 1.minute.ago,
                                               :vm_or_template_id => record.id,
                                               :name              => 'EvmSnapshot',
                                               :description       => "Some Description",
                                               :current           => current)]
        record
      end
      context 'and the selected snapshot is not active' do
        let(:active) { false }
        it_behaves_like 'a disabled button', 'Select the Active snapshot to create a new snapshot for this VM'
      end
      context 'and the selected snapshot may be active but the vm is not connected to a host' do
        let(:record) { FactoryGirl.create(:vm_vmware) }
        it_behaves_like 'a disabled button', 'The VM is not connected to a Host'
      end
      context 'and the selected snapshot is active and current' do
        context 'and current' do
          it_behaves_like 'an enabled button'
        end
        context 'but not current' do
          let(:current) { 0 }
          it_behaves_like 'a disabled button',
                          'At least one snapshot has to be active to create a new snapshot for this VM'
        end
      end
    end
    context 'when creating snapshots is not available' do
      let(:record) { FactoryGirl.create(:vm_amazon) }
      it_behaves_like 'a disabled button', 'Create Snapshot operation not supported for Amazon VM'
    end
  end
end
