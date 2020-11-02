RSpec.describe AnsiblePlaybookMixin do
  let(:test_instance) do
    Class.new(ActiveRecord::Base) do
      def self.name; "TestClass"; end
      self.table_name = "services"
      include AnsiblePlaybookMixin
    end.new
  end

  let(:job)    { FactoryBot.create(:embedded_ansible_job, :name => 'ansible_playbook_mixin_test') }
  let(:task)   { FactoryBot.create(:miq_task) }
  let(:status) { ManageIQ::Providers::EmbeddedAnsible::AutomationManager::Job::Status.new(task, MiqTask::STATUS_OK) }

  context "#playbook_log_stdout" do
    it "returns if the log option is not on_error or always" do
      expect(test_instance.playbook_log_stdout('test', job)).to be_nil
    end

    it "returns if the log option is on_error but the job's raw_status is succeeded" do
      allow(status).to receive(:succeeded?).and_return(true)
      allow(job).to receive(:raw_status).and_return(status)
      expect(test_instance.playbook_log_stdout('on_error', job)).to be_nil
    end

    it "logs the expected message if the log option is not on_error, and the job has succeeded" do
      allow(job).to receive(:raw_stdout).with('txt_download').and_return("<test ansible text>")
      expect($log).to receive(:info).with("Stdout from ansible job ansible_playbook_mixin_test: <test ansible text>")
      test_instance.playbook_log_stdout('always', job)
    end

    it "raises an error if the job is nil" do
      expect($log).to receive(:error).with("Job was nil, must pass a valid job")
      expect($log).to receive(:log_backtrace)
      test_instance.playbook_log_stdout('always', nil)
    end
  end
end
