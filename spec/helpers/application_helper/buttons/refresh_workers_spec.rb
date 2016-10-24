describe ApplicationHelper::Button::RefreshWorkers do
  before :all do
    @records = [FactoryGirl.create(:miq_server), FactoryGirl.create(:miq_region)]
  end

  describe '#visible?' do
    context 'when layout == ops and active_tab == diagnostics_workers in :diagnostics_tree' do
      it 'will not be skipped' do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => nil, 'layout' => 'ops'}, {})
        button.instance_variable_set(:@sb, :active_tab => 'diagnostics_workers')
        allow(view_context).to receive(:x_active_tree).and_return(:diagnostics_tree)
        expect(button.visible?).to be_truthy
      end
    end

    context 'when layout != ops and' do
      %w(miq_server miq_region).each_with_index do |record, i|
        context "record is #{record}" do
          it 'will be skipped' do
            view_context = setup_view_context_with_sandbox({})
            button = described_class.new(view_context, {}, {'record' => @records[i], 'layout' => 'not ops'}, {})
            button.instance_variable_set(:@sb, :active_tab => 'does not matter')
            allow(view_context).to receive(:x_active_tree).and_return(:diagnostics_tree)
            expect(button.visible?).to be_falsey
          end
        end
      end
    end

    %w(download_logs evm_logs audit_logs).each do |lastaction|
      context "when action #{lastaction} being taken as last" do
        it 'will be skipped for this record' do
          view_context = setup_view_context_with_sandbox({})
          button = described_class.new(view_context, {}, {'record' => nil, 'lastaction' => lastaction}, {})
          expect(button.visible?).to be_falsey
        end
      end
    end

    context 'when other action being taken as last' do
      it 'will not be skipped for this record' do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'record' => nil, 'lastaction' => 'worker_logs'}, {})
        expect(button.visible?).to be_truthy
      end
    end
  end
end
