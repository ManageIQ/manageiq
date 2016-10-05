describe ApplicationHelper::Button::TemplateRefresh do
  describe '#visible?' do
    context "when record is refreshable" do
      before do
        @record = FactoryGirl.create(:vm_vmware)
        allow(@record).to receive(:ext_management_system).and_return(true)
      end

      it_behaves_like "will not be skipped for this record"
    end

    context "when record is not refreshable but @perf_options[:typ] is 'realtime'" do
      before do
        @record = FactoryGirl.create(:vm_vmware)
        @perf_options = {:typ => "realtime"}
        allow(@record).to receive(:ext_management_system).and_return(false)
      end

      it "will not be skipped for this record" do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'perf_options' => @perf_options, 'record' => @record}, {})
        expect(button.visible?).to be_truthy
      end
    end

    context "when record is not refreshable but @perf_options[:typ] is 'realtime'" do
      before do
        @record = FactoryGirl.create(:vm_vmware)
        @perf_options = {:typ => "Hourly"}
        allow(@record).to receive(:ext_management_system).and_return(false)
      end

      it "will be skipped for this record" do
        view_context = setup_view_context_with_sandbox({})
        button = described_class.new(view_context, {}, {'perf_options' => @perf_options, 'record' => @record}, {})
        expect(button.visible?).to be_falsey
      end
    end
  end
end
