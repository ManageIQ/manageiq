describe GitRepositoryService do
  let(:git_repository_service) { described_class.new }
  describe "#setup" do
    let(:git_url) { "http://example.com/" }
    let(:git_username) { nil }
    let(:git_password) { nil }
    let(:new_record) { false }

    context "when the git repository already exists" do
      let!(:git_repo) { GitRepository.create!(:url => "http://example.com/") }

      shared_examples_for "GitRepositoryService#setup when verify_ssl is 'true'" do
        it "sets the verify_ssl setting to verify_peer" do
          git_repository_service.setup(git_url, git_username, git_password, verify_ssl)
          expect(git_repo.reload.verify_ssl).to eq(OpenSSL::SSL::VERIFY_PEER)
        end
      end

      shared_examples_for "GitRepositoryService#setup with an existing repo" do
        it "returns the id and the fact that it is not a new repo" do
          expect(git_repository_service.setup(git_url, git_username, git_password, verify_ssl)).to eq(
            :git_repo_id => git_repo.id, :new_git_repo? => false
          )
        end
      end

      context "when verify_ssl is 'true'" do
        let(:verify_ssl) { "true" }

        context "when git username is present" do
          let(:git_username) { "username" }

          context "when git password is present" do
            let(:git_password) { "password" }

            before do
              allow(MiqQueue).to receive(:put_unless_exists)
            end

            it "updates the authentication" do
              git_repository_service.setup(git_url, git_username, git_password, verify_ssl)
              authentication = git_repo.authentications.first
              expect(authentication.userid).to eq("username")
              expect(authentication.password).to eq("password")
            end

            it_behaves_like "GitRepositoryService#setup when verify_ssl is 'true'"
            it_behaves_like "GitRepositoryService#setup with an existing repo"
          end

          context "when git password is not present" do
            it_behaves_like "GitRepositoryService#setup when verify_ssl is 'true'"
            it_behaves_like "GitRepositoryService#setup with an existing repo"
          end
        end

        context "when git username is not present" do
          it_behaves_like "GitRepositoryService#setup when verify_ssl is 'true'"
          it_behaves_like "GitRepositoryService#setup with an existing repo"
        end
      end

      context "when verify_ssl is not 'true'" do
        let(:verify_ssl) { "not true" }

        it "sets the verify_ssl setting to verify_none" do
          git_repository_service.setup(git_url, git_username, git_password, verify_ssl)
          expect(git_repo.reload.verify_ssl).to eq(OpenSSL::SSL::VERIFY_NONE)
        end

        it_behaves_like "GitRepositoryService#setup with an existing repo"
      end
    end

    context "when the git repository does not already exist" do
      shared_examples_for "GitRepositoryService#setup when a git repo does not exist" do
        it "returns the id and the fact that it is a new repo" do
          expect(git_repository_service.setup(git_url, git_username, git_password, verify_ssl)).to eq(
            :git_repo_id => GitRepository.first.id, :new_git_repo? => true
          )
        end
      end

      context "when verify_ssl is 'true'" do
        let(:verify_ssl) { "true" }

        it "creates a git repository with verify_peer" do
          git_repository_service.setup(git_url, git_username, git_password, verify_ssl)
          git_repo = GitRepository.first
          expect(git_repo.verify_ssl).to eq(OpenSSL::SSL::VERIFY_PEER)
        end

        it_behaves_like "GitRepositoryService#setup when a git repo does not exist"
      end

      context "when verify_ssl is not 'true'" do
        let(:verify_ssl) { "not true" }

        it "creates a git repository with verify_none" do
          git_repository_service.setup(git_url, git_username, git_password, verify_ssl)
          git_repo = GitRepository.first
          expect(git_repo.verify_ssl).to eq(OpenSSL::SSL::VERIFY_NONE)
        end

        it_behaves_like "GitRepositoryService#setup when a git repo does not exist"
      end
    end
  end
end
