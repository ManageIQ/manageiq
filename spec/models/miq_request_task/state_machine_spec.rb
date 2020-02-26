RSpec.describe MiqRequestTask do
  let(:task) { FactoryBot.create(:miq_request_task) }

  context "::StateMachine" do
    context "#signal" do
      it "will deal with exceptions" do
        allow(task).to receive_messages(:miq_request => double("MiqRequest").as_null_object)

        expect(task).to receive(:signal).with(:some_state).and_call_original
        expect(task).to receive(:signal).with(:provision_error).and_call_original
        expect(task).to receive(:signal).with(:finish).and_call_original

        expect($log).to receive(:error).with(/NoMethodError/) # There's no 'some_state' method
        expect($log).to receive(:log_backtrace)

        task.signal(:some_state)

        expect(task.status).to eq("Error")
      end
    end
  end
end
