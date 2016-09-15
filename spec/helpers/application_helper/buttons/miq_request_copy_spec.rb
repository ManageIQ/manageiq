describe ApplicationHelper::Button::MiqRequestCopy do
  describe '#skip?' do

    let(:button) do
      described_class.new(
        view_context,
        {},
        {'record' => @record, 'showtype' => @showtype},
        {:options   => {:feature => 'miq_request_copy'}}
      )
    end

    let(:view_context) { setup_view_context_with_sandbox({}) }
    let(:user) {FactoryGirl.create(:user)}
    ["MiqProvisionRequest", "MiqHostProvisionRequest", "VmReconfigureRequest",
     "VmMigrateRequest", "AutomationRequest", "ServiceTemplateProvisionRequest"].each do |cls|
      context 'miq_request_copy' do
        before do
          @record = cls.constantize.new
          allow(@record).to receive_messages(:resource_type  => "MiqProvisionRequest",
                           :approval_state => "pending_approval",
                           :requester_name => user.name)
          allow(button).to receive(:role_allows_feature?).and_return(true)
          allow(button).to receive(:current_user).and_return(user)
          button.instance_variable_set(:@showtype, "prase")
          end

        it "that AutomationRequest will be skipped when miq_request_copy is allowed" do
          allow(@record).to receive_messages(:resource_type => "AutomationRequest")
          expect(button.skipped?).to be_truthy
        end

        it "that AutomationRequest will be skipped when miq_request_copy is denied" do
          allow(@record).to receive_messages(:resource_type => "AutomationRequest")
          allow(button).to receive(:role_allows_feature?).and_return(false)
          expect(button.skipped?).to be_truthy
        end

        it "that SomeRequest will be skipped when miq_request_copy is allowed" do
          allow(@record).to receive_messages(:resource_type => "SomeRequest")
          expect(button.skipped?).to be_truthy
        end

        it "and requester.name != @record.requester_name & showtype = miq_provisions" do
          allow(@record).to receive_messages(:requester_name => 'MojeMama')
          button.instance_variable_set(:@showtype, "miq_provisions")
          expect(button.skipped?).to be_truthy
        end

        it "and approval_state = approved & showtype = miq_provisions" do
          allow(@record).to receive_messages(:approval_state => "approved")
          button.instance_variable_set(:@showtype, "miq_provisions")
          expect(button.skipped?).to be_truthy
        end

        it "and approval_state = denied & showtype = miq_provisions" do
          allow(@record).to receive_messages(:approval_state => "denied")
          button.instance_variable_set(:@showtype, "miq_provisions")
          expect(button.skipped?).to be_truthy
        end

        it "and resource_type = MiqProvisionRequest & requester.name = @record.requester_name & approval_state != approved|denied" do
          button.instance_variable_set(:@showtype, "miq_provisions")
          expect(button.skipped?).to be_falsey
        end

        it "and resource_type = MiqProvisionRequest & showtype != miq_provisions" do
          allow(@record).to receive_messages(:requester_name => 'admin')
          expect(button.skipped?).to be_falsey
        end
      end
    end
  end
end
