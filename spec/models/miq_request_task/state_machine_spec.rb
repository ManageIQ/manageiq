RSpec.describe MiqRequestTask do
  context "::StateMachine" do
    context "#signal" do
      it "will deal with exceptions" do
        task = FactoryBot.create(:miq_request_task)
        allow(task).to receive_messages(:miq_request => double("MiqRequest").as_null_object)
        exception = String.xxx rescue $!
        allow(task).to receive(:some_state).and_raise(exception)

        expect($log).to receive(:error).with(/#{exception.class.name}/)
        expect($log).to receive(:error).with(exception.backtrace.join("\n"))
        expect(task).to receive(:finish)

        task.signal(:some_state)

        expect(task.status).to eq("Error")
      end
    end
  end
end
