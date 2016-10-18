describe ApplicationHelper::Button::RefreshWorkers do
  before :all do
    @record = FactoryGirl.create(
      :assigned_server_role,
      :miq_server => FactoryGirl.create(:miq_server))
  end

  describe '#visible?' do
    %w(download_logs evm_logs audit_logs).each do |lastaction|
      context "action #{lastaction} being taken as last" do
        it 'will be skipped for this record' do
          view_context = setup_view_context_with_sandbox({})
          button = described_class.new(view_context, {}, {'record' => @record, 'lastaction' => lastaction}, {})
          expect(button.visible?).to be_falsey
        end
      end
    end

    context 'other action being taken as last' do
      it 'will not be skipped for this record' do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => @record, 'lastaction' => 'worker_logs'}, {})
        expect(button.visible?).to be_truthy
      end
    end
  end
end
