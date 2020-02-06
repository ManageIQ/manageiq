RSpec.describe GitWorktree do
  context "repository" do
    before do
      @git_db = "TestGit.git"
      @ae_db_dir = Dir.mktmpdir
      @default_hash = {:a => "one", :b => "two", :c => "three"}
      @dirnames = %w(A B c)
      @repo_path = File.join(@ae_db_dir, @git_db)
      @filenames = %w(A/File1.YamL B/File2.YamL c/File3.YAML)
      @deleted_names = %w(A A/File1.YamL)
      @conflict_file = 'A/File1.YamL'
      @master_url = "file://#{@repo_path}"
      @repo_options = {:path     => @repo_path,
                       :username => "user1",
                       :email    => "user1@example.com",
                       :bare     => true,
                       :new      => true}
      @ae_db = GitWorktree.new(@repo_options)
      @original_commit = add_files_to_bare_repo(@filenames)
    end

    after do
      FileUtils.rm_rf(@ae_db_dir) if Dir.exist?(@ae_db_dir)
    end

    def add_files_to_bare_repo(flist)
      flist.each { |f| @ae_db.add(f, YAML.dump(@default_hash.merge(:fname => f))) }
      @ae_db.save_changes("files added")
      @ae_db.instance_variable_get('@repo').head.target.oid
    end

    def clone(url, add_options = {})
      dir = Dir.mktmpdir
      options = {
        :path          => dir,
        :url           => url,
        :username      => "user1",
        :email         => "user1@example.com",
        :ssl_no_verify => true,
        :bare          => true,
        :clone         => true
      }.merge(add_options)
      return dir, GitWorktree.new(options)
    end

    def open_existing_repo
      options = {:path     => @repo_path,
                 :username => "user1",
                 :email    => "user1@example.com"}
      GitWorktree.new(options)
    end

    it "#delete_repo" do
      expect(@ae_db.delete_repo).to be_truthy
      expect(Dir.exist?(@repo_path)).to be_falsey
    end

    it "#remove of existing file" do
      expect { @ae_db.remove('A/File1.YamL') }.to_not raise_error
    end

    it "#remove of non existing file" do
      expect { @ae_db.remove('A/NotExistent.YamL') }.to raise_error(Rugged::IndexError)
    end

    it "#remove_dir existing directory" do
      expect { @ae_db.remove_dir('A') }.to_not raise_error
      expect(@ae_db.file_exists?('A/File1.YamL')).to be_truthy
    end

    it "#file_exists? missing" do
      expect(@ae_db.file_exists?('A/nothing.YamL')).to be_falsey
    end

    it "#read_file that exists" do
      fname = 'A/File1.YamL'
      expect(YAML.load(@ae_db.read_file(fname))).to eq(@default_hash.merge(:fname => fname))
    end

    it "#file_attributes" do
      fname = 'A/File1.YamL'
      expect(@ae_db.file_attributes(fname).keys).to match_array([:updated_on, :updated_by])
    end

    it "#read_file that doesn't exist" do
      expect { @ae_db.read_file('doesnotexist') }.to raise_error(GitWorktreeException::GitEntryMissing)
    end

    it "#entries" do
      expect(@ae_db.entries("")).to match_array(@dirnames)
    end

    it "#entries in A" do
      expect(@ae_db.entries("A")).to match_array(%w(File1.YamL))
    end

    it "get list of files" do
      expect(@ae_db.file_list).to match_array(@filenames + @dirnames)
    end

    it "#directory_exists?" do
      expect(@ae_db.directory_exists?('A')).to be_truthy
    end

    it "#nodes" do
      node = @ae_db.nodes("A").first
      expect(node[:full_name]).to eq("#{@git_db}/A/File1.YamL")
      expect(node[:rel_path]).to eq("A/File1.YamL")
    end

    it "rename directory" do
      filenames = %w(AAA/File1.YamL B/File2.YamL c/File3.YAML)
      dirnames  = %w(AAA B c)
      @ae_db.mv_dir('A', "AAA")
      @ae_db.save_changes("directories moved")
      expect(@ae_db.file_list).to match_array(filenames + dirnames)
    end

    it "rename directory when target exists" do
      expect { @ae_db.mv_dir('A', 'A') }.to raise_error(GitWorktreeException::DirectoryAlreadyExists)
    end

    it "move directories with similar names" do
      filenames = %w(A/A/A/File1.YamL A/A/Aile2.YamL)
      filenames.each { |f| @ae_db.add(f, YAML.dump(@default_hash.merge(:fname => f))) }
      @ae_db.send(:commit, "extra files_added").tap { |cid| @ae_db.send(:merge, cid) }
      @ae_db.mv_dir('A', "AAA")
      @ae_db.save_changes("directories moved")
      filenames = %w(AAA/File1.YamL B/File2.YamL c/File3.YAML AAA/A/A/File1.YamL AAA/A/Aile2.YamL)
      dirnames  = %w(AAA B c AAA/A AAA/A/A)
      expect(@ae_db.file_list).to match_array(filenames + dirnames)
    end

    it "move intermediate directories with similar names" do
      filenames = %w(A/A/A/File1.YamL A/A/Aile2.YamL)
      filenames.each { |f| @ae_db.add(f, YAML.dump(@default_hash.merge(:fname => f))) }
      @ae_db.send(:commit, "extra files_added").tap { |cid| @ae_db.send(:merge, cid) }
      @ae_db.mv_dir('A/A', "AAA")
      @ae_db.save_changes("directories moved")
      filenames = %w(A/File1.YamL B/File2.YamL c/File3.YAML AAA/A/File1.YamL AAA/Aile2.YamL)
      dirnames  = %w(AAA B c AAA/A A)
      expect(@ae_db.file_list).to match_array(filenames + dirnames)
    end

    it "get list of files from a specific commit" do
      @ae_db.remove_dir("A")
      @ae_db.save_changes("directories deleted")
      expect(@ae_db.file_list).to match_array(@filenames + @dirnames - @deleted_names)
      @repo_options[:commit_sha] = @original_commit
      @repo_options[:new] = false
      @orig_db = GitWorktree.new(@repo_options)
      expect(@orig_db.file_list).to match_array(@filenames + @dirnames)
    end

    it "can delete directories" do
      @dirnames.each { |d| @ae_db.remove_dir(d) }
      @ae_db.save_changes("directories deleted")
      @filenames.each { |f| expect(@ae_db.file_exists?(f)).to be_falsey }
    end

    it "rename file with new contents" do
      filenames = %w(A/File11.YamL B/File2.YamL c/File3.YAML)
      @ae_db.mv_file_with_new_contents('A/File1.YamL', 'A/File11.YamL', "Hello")
      @ae_db.save_changes("file renamed")
      expect(@ae_db.file_list).to match_array(filenames + @dirnames)
    end

    it "rename file" do
      filenames = %w(A/File11.YamL B/File2.YamL c/File3.YAML)
      @ae_db.mv_file('A/File1.YamL', 'A/File11.YamL')
      @ae_db.save_changes("file renamed")
      expect(@ae_db.file_list).to match_array(filenames + @dirnames)
    end

    it "manage conflicts" do
      @ae_db.add(@conflict_file, YAML.dump(@default_hash.merge(:fname => "first_one")))
      commit = @ae_db.send(:commit, "suspended commit")

      new_db = open_existing_repo
      new_db.add(@conflict_file, YAML.dump(@default_hash.merge(:fname => "second_one")))
      new_db.save_changes("overlapping commit")
      expect { @ae_db.send(:merge, commit) }.to raise_error { |error|
        expect(error).to be_a(GitWorktreeException::GitConflicts)
      }
    end

    it "clone repo" do
      dirname, c_repo = clone(@master_url)
      expect(c_repo.file_list).to match_array(@ae_db.file_list)
      FileUtils.rm_rf(dirname) if Dir.exist?(dirname)
    end

    it "push changes to master repo" do
      dirname, c_repo = clone(@master_url)
      new_file = "A/File12.yamL"
      c_repo.add(new_file, YAML.dump(@default_hash.merge(:fname => "new1")))
      c_repo.save_changes("new file added on slave", :remote)
      expect(c_repo.file_list).to match_array(@filenames + @dirnames + [new_file])
      expect(c_repo.file_list).to match_array(@ae_db.file_list)
      FileUtils.rm_rf(dirname) if Dir.exist?(dirname)
    end

    it "push changes to master with no conflicts" do
      dirname, c_repo = clone(@master_url)
      new_file_m = "A/File_on_master.yamL"
      new_file_c = "A/File_on_slave.yamL"
      @ae_db.add(new_file_m, YAML.dump(@default_hash.merge(:fname => "new on master")))
      @ae_db.save_changes("new file added in master")
      c_repo.add(new_file_c, YAML.dump(@default_hash.merge(:fname => "new1")))
      c_repo.save_changes("new file added on slave", :remote)
      expect(c_repo.file_list).to match_array(@filenames + @dirnames + [new_file_c, new_file_m])
      expect(c_repo.file_list).to match_array(@ae_db.file_list)
      FileUtils.rm_rf(dirname) if Dir.exist?(dirname)
    end

    it "push changes to master with conflicts" do
      dirname, c_repo = clone(@master_url)
      new_file = "conflict_file.yaml"
      master_data = "on master"
      @ae_db.add(new_file, master_data)
      @ae_db.save_changes("updated on master")
      c_repo.add(new_file, "on slave")
      expect { c_repo.save_changes("updated on slave", :remote) }.to raise_error(GitWorktreeException::GitConflicts)
      expect(@ae_db.file_list).to match_array(@filenames + @dirnames + [new_file])
      expect(c_repo.file_list).to match_array(@ae_db.file_list)
      expect(c_repo.read_entry(c_repo.find_entry(new_file))).to eql(master_data)
      FileUtils.rm_rf(dirname) if Dir.exist?(dirname)
    end

    it "pull updates in a cloned repo" do
      dirname, c_repo = clone(@master_url)
      expect(c_repo.file_list).to match_array(@ae_db.file_list)
      @ae_db.mv_file_with_new_contents('A/File1.YamL', 'A/File11.YamL', "Hello")
      @ae_db.save_changes("file renamed in master")
      c_repo.send(:pull)
      expect(c_repo.file_list).to match_array(@ae_db.file_list)
      FileUtils.rm_rf(dirname) if Dir.exist?(dirname)
    end

    context "with proxy options" do
      let(:proxy_url) { "http://example.com/my_proxy" }

      describe ".new" do
        it "clones the repo using the proxy url" do
          expect(Rugged::Repository).to receive(:clone_at).with(@master_url, anything, hash_including(:proxy_url => proxy_url))
          clone(@master_url, :proxy_url => proxy_url)
        end
      end

      describe "#pull (private)" do
        it "fetches the repo with proxy options" do
          _dir, worktree = clone(@master_url)
          expect(worktree.instance_variable_get(:@repo)).to receive(:fetch).with("origin", hash_including(:proxy_url => proxy_url))

          worktree.instance_variable_set(:@proxy_url, proxy_url)

          worktree.send(:pull)
        end
      end
    end
  end

  describe "git branches" do
    let(:git_repo_path) { Rails.root.join("spec/fixtures/git_repos/branch_and_tag.git") }
    let(:test_repo) { GitWorktree.new(:path => git_repo_path.to_s) }

    describe "#branches" do
      it "all branches" do
        expect(test_repo.branches).to match_array(%w(master branch1 branch2))
      end

      it "local branches only" do
        expect(test_repo.branches(:local)).to match_array(%w(master branch1 branch2))
      end

      it "remote branches only" do
        expect(test_repo.branches(:remote)).to be_empty
      end
    end

    describe "#file_list" do
      it "get list of files in a branch" do
        test_repo.branch = 'branch2'

        expect(test_repo.file_list).to match_array(%w(file1 file2 file3 file4))
      end
    end

    describe "#branch_info" do
      it "get branch info" do
        expect(test_repo.branch_info('branch2').keys).to match_array([:time, :message, :commit_sha])
      end
    end

    describe "#branch" do
      it "non existent branch" do
        expect { test_repo.branch = 'nada' }.to raise_exception(GitWorktreeException::BranchMissing)
      end
    end
  end

  describe "git branches with no master" do
    let(:git_repo_path) { Rails.root.join("spec/fixtures/git_repos/no_master.git") }
    let(:test_repo) { GitWorktree.new(:path => git_repo_path.to_s) }

    describe "#branches" do
      it "all branches" do
        expect(test_repo.branches).to match_array(%w(branch1 branch2))
      end
    end

    describe "#file_list" do
      it "get list of files in a branch" do
        test_repo.branch = 'branch2'

        expect(test_repo.file_list).to match_array(%w(file1 file2 file3 file4))
      end
    end
  end

  describe 'git tags' do
    let(:git_repo_path) { Rails.root.join("spec/fixtures/git_repos/branch_and_tag.git") }
    let(:test_repo) { GitWorktree.new(:path => git_repo_path.to_s) }

    describe "#tags" do
      it "get list of tags" do
        expect(test_repo.tags).to match_array(%w(tag1 tag2))
      end
    end

    describe "#file_list" do
      it "get list of files in a tag" do
        test_repo.tag = 'tag2'
        expect(test_repo.file_list).to match_array(%w(file1 file2 file3 file4))
      end
    end

    describe "#tag_info" do
      it "get tag info" do
        expect(test_repo.tag_info('tag2').keys).to match_array([:time, :message, :commit_sha])
      end
    end

    describe "#tag" do
      it "non existent tag" do
        expect { test_repo.tag = 'nada' }.to raise_exception(GitWorktreeException::TagMissing)
      end
    end
  end

  describe "#new" do
    let(:git_repo_path) { Rails.root.join("spec", "fixtures", "git_repos", "branch_and_tag.git") }

    it "raises an exception if SSH requested, but rugged is not compiled with SSH support" do
      require "rugged"
      expect(Rugged).to receive(:features).and_return([:threads, :https])

      expect {
        GitWorktree.new(:path => git_repo_path, :ssh_private_key => "fake key\nfile content")
      }.to raise_error(GitWorktreeException::InvalidCredentialType)
    end
  end

  describe "#with_remote_options" do
    let(:git_repo_path) { Rails.root.join("spec", "fixtures", "git_repos", "branch_and_tag.git") }

    subject do
      repo.with_remote_options do |cred_options|
        cred_options[:credentials].call("url", nil, [])
      end
    end

    describe "via plaintext" do
      let(:repo) { described_class.new(:path => git_repo_path.to_s, :username => username, :password => password) }
      let(:username) { "fred" }
      let(:password) { "pa$$w0rd" }

      it "with both username and password" do
        expect(subject).to be_a Rugged::Credentials::UserPassword
      end

      context "with no username" do
        let(:username) { nil }

        it "raises an exception" do
          expect { subject }.to raise_error(GitWorktreeException::InvalidCredentials, /provide username and password for/)
        end
      end

      context "with no password" do
        let(:password) { nil }

        it "raises an exception" do
          expect { subject }.to raise_error(GitWorktreeException::InvalidCredentials, /provide username and password for/)
        end
      end
    end

    describe "via SSH" do
      let(:repo) { described_class.new(:path => git_repo_path.to_s, :username => username, :ssh_private_key => ssh_private_key, :password => password) }
      let(:username) { "git" }
      let(:ssh_private_key) { "fake key\nfile content" }
      let(:password) { "pa$$w0rd" }

      before do
        require "rugged"
        allow(Rugged).to receive(:features).and_return([:threads, :https, :ssh])
      end

      it "with username, ssh_private_key, and password" do
        expect(subject).to be_a Rugged::Credentials::SshKey
      end

      context "with no username" do
        let(:username) { nil }

        it "raises an exception" do
          expect { subject }.to raise_error(GitWorktreeException::InvalidCredentials, /provide username for/)
        end
      end

      context "with no password" do
        let(:password) { nil }

        it "creates a password-less ssh key cred" do
          expect(subject).to be_a Rugged::Credentials::SshKey
        end
      end

      context "with no ssh_private_key" do
        let(:ssh_private_key) { nil }

        it "treats it like a user/pass" do
          expect(subject).to be_a Rugged::Credentials::UserPassword
        end
      end
    end
  end
end
