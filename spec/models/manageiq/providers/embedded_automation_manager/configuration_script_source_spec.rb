RSpec.describe ManageIQ::Providers::EmbeddedAutomationManager::ConfigurationScriptSource do
  let(:subject) { FactoryBot.create(:embedded_automation_configuration_script_source, :scm_url => "https://example.com/foo.git") }
  let(:git_repository) { FactoryBot.create(:git_repository) }

  describe "#checkout_git_repository" do
    before do
      expect(subject.git_repository).to receive(:update_repo)
      expect(subject.git_repository).to receive(:checkout)
    end

    context "without a block" do
      it "creates a temporary directory" do
        expect(Dir).to receive(:mktmpdir).and_return("/tmp/mydir")

        subject.checkout_git_repository
      end

      it "doesn't delete the temporary directory" do
        expect(Dir).to           receive(:mktmpdir).and_return("/tmp/mydir")
        expect(FileUtils).not_to receive(:rm_rf)

        subject.checkout_git_repository
      end

      it "doesn't create a new temp dir when passing in a target directory" do
        expect(Dir).not_to receive(:mktmpdir)

        subject.checkout_git_repository("/tmp/mydir")
      end
    end

    context "with a block" do
      it "creates a temporary directory and deletes it" do
        expect(Dir).to       receive(:mktmpdir).and_return("/tmp/mydir")
        expect(FileUtils).to receive(:rm_rf).with("/tmp/mydir")

        subject.checkout_git_repository { |target_directory| target_directory }
      end

      it "deletes the temporary directory if the block raises an exception" do
        expect(Dir).to       receive(:mktmpdir).and_return("/tmp/mydir")
        expect(FileUtils).to receive(:rm_rf).with("/tmp/mydir")

        expect { subject.checkout_git_repository { |_| raise "Exception" } }.to raise_error(RuntimeError, "Exception")
      end

      it "doesn't create a new temp dir when passing in a target directory" do
        expect(Dir).not_to       receive(:mktmpdir)
        expect(FileUtils).not_to receive(:rm_rf).with("/tmp/mydir")

        subject.checkout_git_repository("/tmp/mydir") { |target_directory| target_directory }
      end
    end
  end
end
