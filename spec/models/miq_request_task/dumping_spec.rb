RSpec.describe MiqRequestTask do
  context "::Dumping" do
    let(:task) { FactoryBot.create(:miq_request_task) }

    describe '.dump_obj' do
      it 'accepts a hash' do
        expect(task.class).to receive(:dump_hash)
        task.class.dump_obj(:param_1 => 1)
      end

      it 'accepts an array' do
        expect(task.class).to receive(:dump_array)
        task.class.dump_obj(%w(1 2 3))
      end
    end

    describe '#dump_obj' do
      it "calls .dump_obj" do
        expect(task.class).to receive(:dump_obj)
        task.dump_obj(:param_1 => 1)
      end

      it 'hides passwords' do
        expect($log).to receive(:info).with(/<PROTECTED>/)
        task.dump_obj({:my_password => "secret"}, "my choices: ", $log, :info, :protected => {:path => /[Pp]assword/})
      end
    end
  end
end
