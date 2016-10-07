describe ApplicationHelper::Button::MiqRequestCopy do
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
    %w(MiqProvisionRequest MiqHostProvisionRequest VmReconfigureRequest
       VmMigrateRequest AutomationRequest ServiceTemplateProvisionRequest).each do |cls|

      let(:request) { "MiqProvisionRequest" }
      let(:username) { user.name }
      let(:state) { "pending_approval" }
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
        it "that AutomationRequest will be skipped when miq_request_copy is allowed" do
          expect(button.skipped?).to be_truthy
        end

        it "that AutomationRequest will be skipped when miq_request_copy is denied" do
          allow(button).to receive(:role_allows_feature?).and_return(false)
          expect(button.skipped?).to be_truthy
        end
      end

      context "resource_type = SomeRequest" do
        let(:request) { "SomeRequest" }
        it "that SomeRequest will be skipped when miq_request_copy is allowed" do
          expect(button.skipped?).to be_truthy
        end
      end

      context "showtype = miq_provisions" do
        let(:showtype) { "miq_provisions" }
        context "requester_name = MojeMama" do
          let(:username) { "MojeMama" }
          it "and requester.name != @record.requester_name & showtype = miq_provisions" do
            button.instance_variable_set(:@showtype, "miq_provisions")
            expect(button.skipped?).to be_truthy
          end
        end

        context "approval_state = approved" do
          let(:state) { "approved" }
          it "and approval_state = approved & showtype = miq_provisions" do
            button.instance_variable_set(:@showtype, "miq_provisions")
            expect(button.skipped?).to be_truthy
          end
        end

        context "approval_state = denied" do
          let(:state) { "denied" }
          it "and approval_state = denied & showtype = miq_provisions" do
            button.instance_variable_set(:@showtype, "miq_provisions")
            expect(button.skipped?).to be_truthy
          end
        end

        it "and resource_type = MiqProvisionRequest & requester.name = @record.requester_name & approval_state != approved|denied" do
          button.instance_variable_set(:@showtype, "miq_provisions")
          expect(button.skipped?).to be_falsey
        end
      end

      context "requester_name = admin" do
        let(:username) { 'admin' }
        it "and resource_type = MiqProvisionRequest & showtype != miq_provisions" do
          allow(@record).to receive_messages(:requester_name => 'admin')
          expect(button.skipped?).to be_falsey
        end
      end
    end
  end
end
