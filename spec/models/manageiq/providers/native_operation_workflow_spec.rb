RSpec.describe ManageIQ::Providers::NativeOperationWorkflow do
  context "post_refresh" do
    before do
      vm = FactoryBot.create(:vm)

      options = {
        :target_id    => vm.id,
        :target_class => vm.class.name,
      }

      @job = described_class.create_job(options)
      @job.state = 'refreshing'
    end

    it 'with a successful job' do
      @job.status = "ok"

      expect(Notification).to receive(:create)
      @job.signal(:post_refresh)
    end

    it 'with an unsuccessful job' do
      @job.status = "error"

      expect(Notification).to receive(:create)
      @job.signal(:post_refresh)
    end
  end
end
