describe ApplicationHelper::Button::RoleStart do
  let(:view_context) { setup_view_context_with_sandbox({}) }
  subject { described_class.new(view_context, {}, {'record' => record}, {}) }

  before { allow(view_context).to receive(:x_active_tree).and_return(:diagnostics_tree) }
  before { subject.instance_variable_set(:@sb, {:active_tab => "diagnostics_roles_servers"}) }

  describe '#visible?' do
    context 'when record is assigned server role and miq server is started' do
      let(:record) do
        FactoryGirl.create(:assigned_server_role,
          :miq_server => FactoryGirl.create(:miq_server)
        )
      end
      before { allow(record.miq_server).to receive(:started?).and_return(true) }
      it { expect(subject.visible?).to be_truthy }
    end

    context 'when record is server role' do
      let(:record) { FactoryGirl.create(:server_role, :name => 'server_role') }
      it { expect(subject.visible?).to be_falsey }
    end

    context 'when record is miq server' do
      let(:record) { FactoryGirl.create(:miq_server) }
      it { expect(subject.visible?).to be_falsey }
    end
  end

  describe '#disabled?' do
    context 'when record is assigned server role' do
      let(:record) { FactoryGirl.create(:assigned_server_role) }
      before { allow(record).to receive(:active?).and_return(true) }
      before { subject.calculate_properties }
      it { expect(subject.disabled?).to be_truthy }
      it { expect(subject[:title]).to eq("This Role is already active on this Server") }
    end

    context 'when record is inactive assigned server role' do
      let(:record) do
        FactoryGirl.create(:assigned_server_role,
          :active => false,
          :miq_server => FactoryGirl.create(:miq_server)
        )
      end
      before { allow(record.miq_server).to receive(:started?).and_return(false) }
      before { subject.calculate_properties }
      it { expect(subject.disabled?).to be_truthy }
      it { expect(subject[:title]).to eq("Only available Roles on active Servers can be started") }
    end

    context 'when record is inactive assigned server role' do
      let(:record) do
        FactoryGirl.create(:assigned_server_role,
          :active => false,
          :miq_server => FactoryGirl.create(:miq_server),
          :server_role => FactoryGirl.create(:server_role,
            :name => "server_role"
          )
        )
      end
      before { allow(record.server_role).to receive(:regional_role?).and_return(true) }
      before { allow(record.miq_server).to receive(:started?).and_return(true) }
      before { allow(view_context).to receive(:x_node).and_return('z-1r23') }
      before { subject.calculate_properties }
      it { expect(subject.disabled?).to be_truthy }
      it { expect(subject[:title]).to eq("This role can only be managed at the Region level") }
    end
  end
end
