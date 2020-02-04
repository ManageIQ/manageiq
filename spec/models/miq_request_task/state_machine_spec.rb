RSpec.describe MiqRequestTask do
  let(:task) { FactoryBot.create(:miq_request_task) }

  context "::StateMachine" do
    context "#signal" do
      it "will deal with exceptions" do
        allow(task).to receive_messages(:miq_request => double("MiqRequest").as_null_object)
        exception = String.xxx rescue $!
        allow(task).to receive(:send).with(:some_state).and_raise(exception)

        expect($log).to receive(:error).with(/#{exception.class.name}/)
        expect($log).to receive(:error).with(exception.backtrace.join("\n"))

        expect(task).to receive(:signal).with(:some_state)
        expect(task).to receive(:signal).with(:provision_error)
        expect(task).to receive(:signal).with(:finish)

        task.signal(:some_state)

        expect(task.status).to eq("Error")
      end
    end
  end
end
