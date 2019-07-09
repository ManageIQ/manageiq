describe MiqRequestTask do
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

    describe "#requeue_phase" do
      before { allow(MiqServer).to receive(:my_server).and_return(double(:id => 123)) }
      let(:task) do
        FactoryBot.create(:miq_request_task).tap do |task|
          allow(task).to receive(:my_role)
          allow(task).to receive(:my_zone)
        end
      end

      describe 'will honor max_retries' do
        it 'when exeeds' do
          task.options = { :executed_on_servers => [1, 1, 1] }
          expect { task.requeue_phase(:max_retries => 3) }.to raise_error(/max retries exceeded/)
        end

        it 'when not exeeds' do
          task.options = { :executed_on_servers => [1, 1] }
          expect { task.requeue_phase(:max_retries => 3) }.not_to raise_error
        end
      end
    end
  end
end
