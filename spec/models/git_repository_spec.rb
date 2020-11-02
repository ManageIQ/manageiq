RSpec.describe GitRepository do
  describe "#url" do
    it "missing" do
      expect(FactoryBot.build(:git_repository, :url => nil)).to_not be_valid
    end

    it "invalid" do
      expect(FactoryBot.build(:git_repository, :url => "abc")).to_not be_valid
    end

    it "http" do
      expect(FactoryBot.build(:git_repository, :url => "http://example.com/ManageIQ/manageiq.git")).to be_valid
    end

    it "https" do
      expect(FactoryBot.build(:git_repository, :url => "https://example.com/ManageIQ/manageiq.git")).to be_valid
    end

    it "file" do
      expect(FactoryBot.build(:git_repository, :url => "file:///home/foo/ManageIQ/manageiq")).to be_valid
    end

    it "ssh" do
      expect(FactoryBot.build(:git_repository, :url => "ssh://example.com/ManageIQ/manageiq.git")).to be_valid
    end

    it "ssh user@host:path" do
      expect(FactoryBot.build(:git_repository, :url => "git@example.com:ManageIQ/manageiq.git")).to be_valid
    end
  end

  it "default dirname" do
    repo = FactoryBot.create(:git_repository, :url => "http://www.example.com/repos/manageiq")
    expect(repo.directory_name).to eq(File.join(described_class::GIT_REPO_DIRECTORY, repo.id.to_s))
  end

  context "repo" do
    let(:gwt) { instance_double('GitWorktree') }
    let(:verify_ssl) { OpenSSL::SSL::VERIFY_PEER }
    let(:branch_list) { %w(b1 b2) }
    let(:tag_list) { %w(t1 t2) }
    let(:info) { {:time => Time.now.utc, :message => "R2D2", :commit_sha => "abcdef"} }
    let(:branch_info_hash) do
      {'b1' => {:time => Time.now.utc, :message => "B1", :commit_sha => "abcdef"},
       'b2' => {:time => Time.now.utc - 5, :message => "B2", :commit_sha => "123456"}
      }
    end
    let(:tag_info_hash) do
      {'t1' => {:time => Time.now.utc, :message => "T1", :commit_sha => "abc12f"},
       't2' => {:time => Time.now.utc + 5, :message => "T2", :commit_sha => "123456"}
      }
    end
    let(:repo) { FactoryBot.create(:git_repository, :verify_ssl => verify_ssl) }
    let(:userid) { 'user' }
    let(:password) { 'password' }

    context "parameter check" do
      let(:args) do
        {
          :username => userid,
          :password => password,
          :path     => repo.directory_name,
        }
      end

      let(:clone_args) do
        args.merge(
          :url   => repo.url,
          :clone => true
        )
      end

      before do
        allow(MiqServer).to receive(:my_zone).and_return("default")
        allow(gwt).to receive(:branches).with(anything).and_return(branch_list)
        allow(gwt).to receive(:tags).with(no_args).and_return(tag_list)
        allow(gwt).to receive(:branch_info) do |name|
          branch_info_hash[name]
        end
        allow(gwt).to receive(:tag_info) do |name|
          tag_info_hash[name]
        end
      end

      it "userid and password is set" do
        repo.update_authentication(:default => {:userid => userid, :password => password})
        expect(GitWorktree).to receive(:new).with(clone_args).and_return(gwt)
        expect(GitWorktree).to receive(:new).with(args).and_return(gwt)
        expect(gwt).to receive(:pull).with(no_args)

        repo.refresh
        expect(repo.default_authentication.userid).to eq(userid)
        expect(repo.default_authentication.password).to eq(password)
      end

      it "sends the proxy settings to the worktree instance" do
        proxy_settings = {
          :git_repository_proxy => {
            :host   => "example.com",
            :port   => "80",
            :scheme => "http",
            :path   => "/proxy"
          }
        }
        stub_settings(proxy_settings)
        expect(GitWorktree).to receive(:new).with(hash_including(:proxy_url => "http://example.com:80/proxy")).twice.times.and_return(gwt)
        expect(gwt).to receive(:pull).with(no_args)

        repo.refresh
      end

      it "doesn't send the proxy settings if the proxy scheme is not http or https" do
        proxy_settings = {
          :git_repository_proxy => {
            :host   => "example.com",
            :port   => "12345",
            :scheme => "socks5"
          }
        }
        stub_settings(proxy_settings)
        expect(GitWorktree).to receive(:new) do |options|
          expect(options[:proxy_url]).to be_nil
        end.twice.and_return(gwt)

        expect(gwt).to receive(:pull).with(no_args)

        repo.refresh
      end

      it "doesn't send the proxy settings if the repo scheme is not http or https" do
        proxy_settings = {
          :git_repository_proxy => {
            :host   => "example.com",
            :port   => "3128",
            :scheme => "http"
          }
        }
        stub_settings(proxy_settings)
        expect(GitWorktree).to receive(:new) do |options|
          expect(options[:proxy_url]).to be_nil
        end.twice.and_return(gwt)

        expect(gwt).to receive(:pull).with(no_args)

        repo.update!(:url => "git@example.com:ManageIQ/manageiq.git")
        repo.refresh
      end

      context "self signed certifcate" do
        let(:verify_ssl) { OpenSSL::SSL::VERIFY_NONE }

        it "certificate_check is set" do
          repo.update_authentication(:default => {:userid => userid, :password => password})
          args[:certificate_check] = repo.method(:self_signed_cert_cb)
          expect(GitWorktree).to receive(:new).with(clone_args).and_return(gwt)
          expect(GitWorktree).to receive(:new).with(args).and_return(gwt)
          expect(gwt).to receive(:pull).with(no_args)

          repo.refresh
        end
      end
    end

    it "#refresh" do
      expect(GitWorktree).to receive(:new).with(anything).and_return(gwt)
      expect(gwt).to receive(:branches).with(anything).and_return(branch_list)
      expect(gwt).to receive(:tags).with(no_args).and_return(tag_list)
      allow(gwt).to receive(:branch_info) do |name|
        branch_info_hash[name]
      end
      allow(gwt).to receive(:tag_info) do |name|
        tag_info_hash[name]
      end

      expect(repo).to receive(:clone_repo_if_missing).once.with(no_args).and_call_original
      expect(GitWorktree).to receive(:new).with(anything).and_return(gwt)
      expect(gwt).to receive(:pull).with(no_args)

      repo.refresh
      expect(repo.git_branches.collect(&:name)).to match_array(branch_list)
      expect(repo.git_tags.collect(&:name)).to match_array(tag_list)
    end

    it "#branch_info" do
      expect(GitWorktree).to receive(:new).twice.with(anything).and_return(gwt)
      expect(gwt).to receive(:branches).with(anything).and_return(branch_list)
      expect(gwt).to receive(:tags).with(no_args).and_return(tag_list)
      expect(gwt).to receive(:pull).with(no_args)

      allow(gwt).to receive(:branch_info) do |name|
        branch_info_hash[name]
      end
      allow(gwt).to receive(:tag_info) do |name|
        tag_info_hash[name]
      end

      attrs = repo.branch_info('b1')
      expect(attrs['commit_sha']).to eq(info[:commit_sha])
    end

    it "#tag_info" do
      expect(GitWorktree).to receive(:new).twice.with(anything).and_return(gwt)
      expect(gwt).to receive(:branches).with(anything).and_return(branch_list)
      expect(gwt).to receive(:tags).with(no_args).and_return(tag_list)
      expect(gwt).to receive(:pull).with(no_args)

      allow(gwt).to receive(:branch_info) do |name|
        branch_info_hash[name]
      end
      allow(gwt).to receive(:tag_info) do |name|
        tag_info_hash[name]
      end

      attrs = repo.tag_info('t1')
      expect(attrs['commit_sha']).to eq(tag_info_hash['t1'][:commit_sha])
    end

    it "#tag_info missing tag" do
      expect(GitWorktree).to receive(:new).twice.with(anything).and_return(gwt)
      expect(gwt).to receive(:branches).with(anything).and_return(branch_list)
      expect(gwt).to receive(:tags).with(no_args).and_return(tag_list)
      expect(gwt).to receive(:pull).with(no_args)

      allow(gwt).to receive(:branch_info) do |name|
        branch_info_hash[name]
      end
      allow(gwt).to receive(:tag_info) do |name|
        tag_info_hash[name]
      end

      expect { repo.tag_info('nothing') }.to raise_error(RuntimeError)
    end

    it "#branch_info missing branch" do
      expect(GitWorktree).to receive(:new).twice.with(anything).and_return(gwt)
      expect(gwt).to receive(:branches).with(anything).and_return(branch_list)
      expect(gwt).to receive(:tags).with(no_args).and_return(tag_list)
      expect(gwt).to receive(:pull).with(no_args)

      allow(gwt).to receive(:branch_info) do |name|
        branch_info_hash[name]
      end
      allow(gwt).to receive(:tag_info) do |name|
        tag_info_hash[name]
      end

      expect { repo.branch_info('nothing') }.to raise_error(RuntimeError)
    end

    it "#refresh branches deleted" do
      expect(GitWorktree).to receive(:new).twice.with(anything).and_return(gwt)
      expect(gwt).to receive(:pull).twice.with(no_args)
      expect(gwt).to receive(:branches).twice.with(anything).and_return(branch_list)
      expect(gwt).to receive(:tags).twice.with(no_args).and_return(tag_list)

      allow(gwt).to receive(:branch_info) do |name|
        branch_info_hash[name]
      end
      allow(gwt).to receive(:tag_info) do |name|
        tag_info_hash[name]
      end

      repo.refresh
      repo.git_branches << FactoryBot.create(:git_branch, :name => 'DUMMY')
      expect(repo.git_branches.collect(&:name)).to match_array(branch_list + ['DUMMY'])
      repo.refresh
      expect(repo.git_branches.collect(&:name)).to match_array(branch_list)
    end

    it "#refresh tags deleted" do
      expect(GitWorktree).to receive(:new).twice.with(anything).and_return(gwt)
      expect(gwt).to receive(:pull).twice.with(no_args)
      expect(gwt).to receive(:branches).twice.with(anything).and_return(branch_list)
      expect(gwt).to receive(:tags).twice.with(no_args).and_return(tag_list)

      allow(gwt).to receive(:branch_info) do |name|
        branch_info_hash[name]
      end
      allow(gwt).to receive(:tag_info) do |name|
        tag_info_hash[name]
      end

      repo.refresh
      repo.git_tags << FactoryBot.create(:git_tag, :name => 'DUMMY')
      expect(repo.git_tags.collect(&:name)).to match_array(tag_list + ['DUMMY'])
      repo.refresh
      expect(repo.git_tags.collect(&:name)).to match_array(tag_list)
    end

    context "#destroy" do
      let(:dir_name) { repo.directory_name }

      context "when repo deletion has no errors" do
        before do
          EvmSpecHelper.create_guid_miq_server_zone
        end

        it "deletes the repo and the directory" do
          expect(FileUtils).to receive(:rm_rf).with(dir_name)

          repo.destroy
          delete_job = MiqQueue.get
          delete_job.deliver
        end
      end

      context "with multiple MiqServers" do
        let(:other_zone) { FactoryBot.create(:zone) }

        let(:other_servers) do
          [
            FactoryBot.create(:miq_server, :guid => SecureRandom.uuid, :zone => other_zone),
            FactoryBot.create(:miq_server, :guid => SecureRandom.uuid, :zone => other_zone)
          ]
        end

        before do
          EvmSpecHelper.create_guid_miq_server_zone
          other_servers
        end

        it "broadcasts the deletes to all servers" do
          expect(FileUtils).to receive(:rm_rf).with(dir_name).exactly(3).times

          repo.destroy
          (other_servers + [MiqServer.my_server]).each do |server|
            EvmSpecHelper.stub_as_local_server(server)

            delete_job = MiqQueue.get
            delete_job.deliver
          end
        end
      end

      context "when repo deletion has errors" do
        before do
          allow(repo).to receive(:broadcast_repo_dir_delete).and_raise(MiqException::Error, "wham")
        end

        it "does not delete the repo and the directory" do
          repo_id = repo.id

          expect { repo.destroy }.to raise_exception(MiqException::Error, "wham")
          expect(GitRepository.find(repo_id)).not_to be_nil
        end
      end
    end

    context "check_connection?" do
      require 'net/ping/external'
      let(:ext_ping) { instance_double(Net::Ping::External) }

      before do
        allow(Net::Ping::External).to receive(:new).and_return(ext_ping)
        allow(ext_ping).to receive(:exception)
      end

      it "returns true if it can ping the repo" do
        allow(ext_ping).to receive(:ping?).and_return(true)
        expect($log).to receive(:debug).with(/pinging '.*' to verify network connection/)
        expect(repo.check_connection?).to eq(true)
      end

      it "returns false if it cannot ping the repo" do
        allow(ext_ping).to receive(:ping?).and_return(false)
        expect($log).to receive(:debug).with(/pinging '.*' to verify network connection/)
        expect($log).to receive(:debug).with(/ping failed: .*/)
        expect(repo.check_connection?).to eq(false)
      end

      it "handles git urls without issue" do
        allow(repo).to receive(:url).and_return("git@example.com:ManageIQ/manageiq.git")
        allow(ext_ping).to receive(:ping?).and_return(true)
        expect($log).to receive(:debug).with(/pinging 'example.com' to verify network connection/)
        expect(repo.check_connection?).to eq(true)
      end

      it "handles ssh urls without issue" do
        allow(repo).to receive(:url).and_return("ssh://user@example.com:443/manageiq.git")
        allow(ext_ping).to receive(:ping?).and_return(true)
        expect($log).to receive(:debug).with(/pinging 'example.com' to verify network connection/)
        expect(repo.check_connection?).to eq(true)
      end

      it "handles file urls without issue" do
        allow(repo).to receive(:url).and_return("file://example.com/server/manageiq.git")
        allow(ext_ping).to receive(:ping?).and_return(true)
        expect($log).to receive(:debug).with(/pinging 'example.com' to verify network connection/)
        expect(repo.check_connection?).to eq(true)
      end
    end
  end
end
