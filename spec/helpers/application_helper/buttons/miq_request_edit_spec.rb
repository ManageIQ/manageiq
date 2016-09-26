describe ApplicationHelper::Button::MiqRequestEdit do
  describe '#visible?' do

    let(:button) do
      described_class.new(
        view_context,
        {},
        {'record' => @record, 'showtype' => @showtype},
        {:options   => {:feature => 'miq_request_copy'}}
      )
    end

    let(:view_context) { setup_view_context_with_sandbox({}) }
    let(:user) { FactoryGirl.create(:user) }
    let(:request) { "SomeRequest" }
    let(:username) { user.name }
    let(:state) { "xx" }
    %w(MiqProvisionRequest MiqHostProvisionRequest VmReconfigureRequest
       VmMigrateRequest AutomationRequest ServiceTemplateProvisionRequest).each do |cls|
      context 'miq_request_edit' do
        before do
          @record = cls.constantize.new
          allow(@record).to receive_messages(:resource_type  => request,
                                             :approval_state => state,
                                             :requester_name => username)
          allow(button).to receive(:role_allows_feature?).and_return(true)
          allow(button).to receive(:current_user).and_return(user)
          button.instance_variable_set(:@showtype, "prase")
        end

        context "resource_type = AutomationRequest" do
          let(:request) { "AutomationRequest" }
          it "and resource_type = AutomationRequest" do
            expect(button.skipped?).to be_truthy
          end
        end

        context "requester_name = admin" do
          let(:username) { 'admin' }
          it "and requester.name != @record.requester_name" do
            expect(button.skipped?).to be_truthy
          end
        end

        context "approval_state = approved" do
          let(:state) { "approved" }
          it "and approval_state = approved" do
            expect(button.skipped?).to be_truthy
          end
        end

        context "approval_state = denied" do
          let(:state) { "denied" }
          it "and approval_state = denied" do
            expect(button.skipped?).to be_truthy
          end
        end

        it "and requester.name = @record.requester_name & approval_state != approved|denied" do
          expect(button.skipped?).to be_truthy
        end
      end
    end
  end
end
