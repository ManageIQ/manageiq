describe ApplicationHelper::Button::RefreshWorkers do
  before :all do
    @record = FactoryGirl.create(
      :assigned_server_role,
      :miq_server => FactoryGirl.create(:miq_server))
  end

  describe '#visible?' do
    it 'should be visible when active_tab == diagnostics_workers in :diagnostics_tree' do
      view_context = setup_view_context_with_sandbox({})
      button = described_class.new(view_context, {}, {'record' => @record}, {})
      button.instance_variable_set(:@sb, :active_tab => 'diagnostics_workers')
      expect(button.visible?).to be_truthy
    end

    %w(download_logs evm_logs audit_logs).each do |lastaction|
      context "action #{lastaction} being taken as last" do
        it 'will be skipped for this record' do
          view_context = setup_view_context_with_sandbox({})
          button = described_class.new(view_context, {}, {'record' => nil, 'lastaction' => lastaction}, {})
          expect(button.visible?).to be_falsey
        end
      end
    end

    context 'other action being taken as last' do
      it 'will not be skipped for this record' do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => nil, 'lastaction' => 'worker_logs'}, {})
        expect(button.visible?).to be_truthy
      end
    end
  end
end
