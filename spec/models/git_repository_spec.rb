describe GitRepository do
  it "no url" do
    expect { FactoryGirl.create(:git_repository) }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "invalid url" do
    expect { FactoryGirl.create(:git_repository, :url => "abc") }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "default dirname" do
    repo = FactoryGirl.create(:git_repository,
                              :url => "http://www.example.com/repos/manageiq")
    expect(repo.directory_name).to eq(File.join(MiqAeDatastore::GIT_REPO_DIRECTORY, 'repos/manageiq'))
  end

  context "repo" do
    let(:gwt) { instance_double('GitWorktree') }
    let(:git_url) { 'http://www.example.com/repo/manageiq' }
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
    let(:repo) { FactoryGirl.create(:git_repository, :url => git_url, :verify_ssl => verify_ssl) }
    let(:userid) { 'user' }
    let(:password) { 'password' }

    context "parameter check" do
      let(:args) do
        {
          :url      => git_url,
          :username => userid,
          :password => password,
          :path     => repo.directory_name,
          :clone    => true
        }
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
        expect(GitWorktree).to receive(:new).with(args).and_return(gwt)
        repo.refresh
      end

      context "self signed certifcate" do
        let(:verify_ssl) { OpenSSL::SSL::VERIFY_NONE }

        it "certificate_check is set" do
          repo.update_authentication(:default => {:userid => userid, :password => password})
          args[:certificate_check] = repo.method(:self_signed_cert_cb)
          expect(GitWorktree).to receive(:new).with(args).and_return(gwt)
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

      expect(repo).to receive(:init_repo).with(no_args).and_call_original

      repo.refresh
      expect(repo.git_branches.collect(&:name)).to match_array(branch_list)
      expect(repo.git_tags.collect(&:name)).to match_array(tag_list)
    end

    it "#branch_info" do
      expect(GitWorktree).to receive(:new).with(anything).and_return(gwt)
      expect(gwt).to receive(:branches).with(anything).and_return(branch_list)
      expect(gwt).to receive(:tags).with(no_args).and_return(tag_list)
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
      expect(GitWorktree).to receive(:new).with(anything).and_return(gwt)
      expect(gwt).to receive(:branches).with(anything).and_return(branch_list)
      expect(gwt).to receive(:tags).with(no_args).and_return(tag_list)
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
      expect(GitWorktree).to receive(:new).with(anything).and_return(gwt)
      expect(gwt).to receive(:branches).with(anything).and_return(branch_list)
      expect(gwt).to receive(:tags).with(no_args).and_return(tag_list)
      allow(gwt).to receive(:branch_info) do |name|
        branch_info_hash[name]
      end
      allow(gwt).to receive(:tag_info) do |name|
        tag_info_hash[name]
      end

      expect { repo.tag_info('nothing') }.to raise_error(RuntimeError)
    end

    it "#branch_info missing branch" do
      expect(GitWorktree).to receive(:new).with(anything).and_return(gwt)
      expect(gwt).to receive(:branches).with(anything).and_return(branch_list)
      expect(gwt).to receive(:tags).with(no_args).and_return(tag_list)
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
      expect(gwt).to receive(:branches).twice.with(anything).and_return(branch_list)
      expect(gwt).to receive(:tags).twice.with(no_args).and_return(tag_list)

      allow(gwt).to receive(:branch_info) do |name|
        branch_info_hash[name]
      end
      allow(gwt).to receive(:tag_info) do |name|
        tag_info_hash[name]
      end

      repo.refresh
      repo.git_branches << FactoryGirl.create(:git_branch, :name => 'DUMMY')
      expect(repo.git_branches.collect(&:name)).to match_array(branch_list + ['DUMMY'])
      repo.refresh
      expect(repo.git_branches.collect(&:name)).to match_array(branch_list)
    end

    it "#refresh tags deleted" do
      expect(GitWorktree).to receive(:new).twice.with(anything).and_return(gwt)
      expect(gwt).to receive(:branches).twice.with(anything).and_return(branch_list)
      expect(gwt).to receive(:tags).twice.with(no_args).and_return(tag_list)

      allow(gwt).to receive(:branch_info) do |name|
        branch_info_hash[name]
      end
      allow(gwt).to receive(:tag_info) do |name|
        tag_info_hash[name]
      end

      repo.refresh
      repo.git_tags << FactoryGirl.create(:git_tag, :name => 'DUMMY')
      expect(repo.git_tags.collect(&:name)).to match_array(tag_list + ['DUMMY'])
      repo.refresh
      expect(repo.git_tags.collect(&:name)).to match_array(tag_list)
    end

    it "#destroy" do
      dir = repo.directory_name
      FileUtils.mkdir_p dir
      expect(Dir.exist?(dir)).to be_truthy
      repo.destroy
      expect(Dir.exist?(dir)).to be_falsey
    end
  end
end
