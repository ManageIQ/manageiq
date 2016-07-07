describe GitBasedDomainImportService do
  describe "#import" do
    let(:git_repo) { double("GitRepository", :git_branches => git_branches, :id => 123) }
    let(:domain) { double("MiqAeDomain") }

    before do
      allow(GitRepository).to receive(:find_by).with(:id => 123).and_return(git_repo)
      allow(domain).to receive(:update_attribute).with(:enabled, true)
    end

    context "when git branches that match the given name exist" do
      let(:git_branches) { [double("GitBranch", :name => "the_branch_name")] }

      before do
        allow(MiqAeDomain).to receive(:import_git_repo).with(
          "git_repository_id" => 123,
          "ref"               => "the_branch_name",
          "ref_type"          => "branch"
        ).and_return(domain)
      end

      it "calls 'import_git_repo' with the correct options" do
        expect(MiqAeDomain).to receive(:import_git_repo).with(
          "git_repository_id" => 123,
          "ref"               => "the_branch_name",
          "ref_type"          => "branch"
        )
        subject.import(123, "the_branch_name")
      end

      it "updates the enabled attribute on the domain to true" do
        expect(domain).to receive(:update_attribute).with(:enabled, true)
        subject.import(123, "the_branch_name")
      end
    end

    context "when git branches that match the given name do not exist" do
      let(:git_branches) { [] }

      before do
        allow(MiqAeDomain).to receive(:import_git_repo).with(
          "git_repository_id" => 123,
          "ref"               => "the_branch_name",
          "ref_type"          => "tag"
        ).and_return(domain)
      end

      it "calls 'import_git_repo' with the correct options" do
        expect(MiqAeDomain).to receive(:import_git_repo).with(
          "git_repository_id" => 123,
          "ref"               => "the_branch_name",
          "ref_type"          => "tag"
        )
        subject.import(123, "the_branch_name")
      end

      it "updates the enabled attribute on the domain to true" do
        expect(domain).to receive(:update_attribute).with(:enabled, true)
        subject.import(123, "the_branch_name")
      end
    end
  end
end
