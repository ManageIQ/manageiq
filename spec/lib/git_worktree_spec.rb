require 'spec_helper'

describe GitWorktree do
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
      options = {:path  => @repo_path,
                 :name  => "user1",
                 :email => "user1@example.com",
                 :bare  => true,
                 :new   => true}
      @ae_db = GitWorktree.new(options)
      @original_commit = add_files_to_bare_repo(@filenames)
    end

    after do
      FileUtils.rm_rf(@ae_db_dir) if Dir.exist?(@ae_db_dir)
    end

    def add_files_to_bare_repo(flist)
      flist.each { |f| @ae_db.add(f, YAML.dump(@default_hash.merge(:fname => f))) }
      @ae_db.commit("files_added").tap { |cid| @ae_db.merge(cid) }
    end

    def clone(url)
      dir = Dir.mktmpdir
      options = {:path  => dir,
                 :url   => url,
                 :name  => "user1",
                 :email => "user1@example.com",
                 :ssl_no_verify => true,
                 :bare  => true,
                 :clone => true}
      return dir, GitWorktree.new(options)
    end

    def open_existing_repo
      options = {:path  => @repo_path,
                 :name  => "user1",
                 :email => "user1@example.com"}
      GitWorktree.new(options)
    end

    it "#delete_repo" do
      @ae_db.delete_repo.should be_true
      Dir.exist?(@repo_path).should be_false
    end

    it "#remove of existing file" do
      expect { @ae_db.remove('A/File1.YamL') }.to_not raise_error
    end

    it "#remove of non existing file" do
      expect { @ae_db.remove('A/NotExistent.YamL') }.to raise_error
    end

    it "#remove_dir existing directory" do
      @ae_db.directory?('A').should be_true
      expect { @ae_db.remove_dir('A') }.to_not raise_error
      @ae_db.file_exists?('A/File1.YamL').should be_true
    end

    it "#read_file that exists" do
      fname = 'A/File1.YamL'
      YAML.load(@ae_db.read_file(fname)).should have_attributes(@default_hash.merge(:fname => fname))
    end

    it "#file_attributes" do
      fname = 'A/File1.YamL'
      @ae_db.file_attributes(fname).keys.should match_array([:updated_on, :updated_by])
    end

    it "#read_file that doesn't exist" do
      expect { @ae_db.read_file('doesnotexist') }.to raise_error(MiqException::MiqGitEntryMissing)
    end

    it "#entries" do
      @ae_db.entries("").should match_array(@dirnames)
    end

    it "#entries in A" do
      @ae_db.entries("A").should match_array(%w(File1.YamL))
    end

    it "get list of files" do
      @ae_db.file_list.should match_array(@filenames + @dirnames)
    end

    it "#directory_exists?" do
      @ae_db.directory_exists?('A').should be_true
    end

    it "#nodes" do
      node = @ae_db.nodes("A").first
      node[:full_name].should eq("#{@git_db}/A/File1.YamL")
      node[:rel_path].should  eq("A/File1.YamL")
    end

    it "rename directory" do
      filenames = %w(AAA/File1.YamL B/File2.YamL c/File3.YAML)
      dirnames  = %w(AAA B c)
      @ae_db.mv_dir('A', "AAA")
      @ae_db.save_changes("directories moved")
      @ae_db.file_list.should match_array(filenames + dirnames)
    end

    it "get list of files from a specific commit" do
      @ae_db.remove_dir("A")
      @ae_db.save_changes("directories deleted")
      @ae_db.file_list.should match_array(@filenames + @dirnames - @deleted_names)
      @ae_db.file_list(@original_commit).should match_array(@filenames + @dirnames)
    end

    it "can delete directories" do
      @dirnames.each { |d| @ae_db.remove_dir(d) }
      @ae_db.save_changes("directories deleted")
      @filenames.each { |f| @ae_db.file_exists?(f).should be_false }
    end

    it "rename file with new contents" do
      filenames = %w(A/File11.YamL B/File2.YamL c/File3.YAML)
      @ae_db.mv_file_with_new_contents('A/File1.YamL', 'A/File11.YamL', "Hello")
      @ae_db.save_changes("file renamed")
      @ae_db.file_list.should match_array(filenames + @dirnames)
    end

    it "rename file" do
      filenames = %w(A/File11.YamL B/File2.YamL c/File3.YAML)
      @ae_db.mv_file('A/File1.YamL', 'A/File11.YamL')
      @ae_db.save_changes("file renamed")
      @ae_db.file_list.should match_array(filenames + @dirnames)
    end

    it "manage conflicts" do
      @ae_db.add(@conflict_file, YAML.dump(@default_hash.merge(:fname => "first_one")))
      commit = @ae_db.commit("suspended commit")

      new_db = open_existing_repo
      new_db.add(@conflict_file, YAML.dump(@default_hash.merge(:fname => "second_one")))
      new_db.save_changes("overlapping commit")
      expect { @ae_db.merge(commit) }.to raise_error { |error|
        expect(error).to be_a(MiqException::MiqGitConflicts)
      }
    end

    it "clone repo" do
      dirname, c_repo = clone(@master_url)
      c_repo.file_list.should match_array(@ae_db.file_list)
      FileUtils.rm_rf(dirname) if Dir.exist?(dirname)
    end

    it "push changes to master repo" do
      dirname, c_repo = clone(@master_url)
      new_file = "A/File12.yamL"
      c_repo.add(new_file, YAML.dump(@default_hash.merge(:fname => "new1")))
      c_repo.save_changes("new file added on slave", :remote)
      c_repo.file_list.should match_array(@filenames + @dirnames + [new_file])
      c_repo.file_list.should match_array(@ae_db.file_list)
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
      c_repo.file_list.should match_array(@filenames + @dirnames + [new_file_c, new_file_m])
      c_repo.file_list.should match_array(@ae_db.file_list)
      FileUtils.rm_rf(dirname) if Dir.exist?(dirname)
    end

    it "push changes to master with conflicts" do
      dirname, c_repo = clone(@master_url)
      new_file = "conflict_file.yaml"
      master_data = "on master"
      @ae_db.add(new_file, master_data)
      @ae_db.save_changes("updated on master")
      c_repo.add(new_file, "on slave")
      expect { c_repo.save_changes("updated on slave", :remote) }.to raise_error(MiqException::MiqGitConflicts)
      @ae_db.file_list.should match_array(@filenames + @dirnames + [new_file])
      c_repo.file_list.should match_array(@ae_db.file_list)
      c_repo.read_entry(c_repo.find_entry(new_file)).should eql(master_data)
      FileUtils.rm_rf(dirname) if Dir.exist?(dirname)
    end

    it "pull updates in a cloned repo" do
      dirname, c_repo = clone(@master_url)
      c_repo.file_list.should match_array(@ae_db.file_list)
      @ae_db.mv_file_with_new_contents('A/File1.YamL', 'A/File11.YamL', "Hello")
      @ae_db.save_changes("file renamed in master")
      c_repo.pull
      c_repo.file_list.should match_array(@ae_db.file_list)
      FileUtils.rm_rf(dirname) if Dir.exist?(dirname)
    end
  end
end
