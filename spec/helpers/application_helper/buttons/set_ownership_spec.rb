describe ApplicationHelper::Button::SetOwnership do
  let(:view_context) { setup_view_context_with_sandbox({}) }

  let(:ext_management_system) do
    FactoryGirl.create(:ext_management_system, :tenant_mapping_enabled => tenant_mapping_enabled)
  end

  let(:record) { FactoryGirl.create(:vm, :ext_management_system => ext_management_system) }

  let(:button) { described_class.new(view_context, {}, {'record' => record}, {}) }

  describe '#calculate_properties' do
    before { button.calculate_properties }

    context 'when provider has tenant mapping enabled' do
      let(:tenant_mapping_enabled) { true }
      it_behaves_like 'a disabled button'
    end

    context 'when provider has tenant mapping disabled' do
      let(:tenant_mapping_enabled) { false }
      it_behaves_like 'an enabled button'
    end

    context 'when vm does not belong to any Vm' do
      let(:ext_management_system)  { nil }
      it_behaves_like 'an enabled button'
    end
  end
end
