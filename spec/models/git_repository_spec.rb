require 'spec_helper'

describe GitRepository do
  it "no url" do
    expect { FactoryGirl.create(:git_repository, :dirname => "abc") }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "invalid url" do
    expect { FactoryGirl.create(:git_repository, :url => "abc") }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "default dirname" do
    repo = FactoryGirl.create(:git_repository,
                              :url => "http://www.something.com/repos/manageiq")
    expect(repo.dirname).to eq(File.join(MiqAeDatastore::GIT_REPO_DIRECTORY, 'repos/manageiq'))
  end

  it "passed in dirname" do
    repo = FactoryGirl.create(:git_repository,
                              :dirname => '/tmp/repodir',
                              :url     => "http://www.a.com/repos/manageiq")
    expect(repo.dirname).to eq('/tmp/repodir')
  end

  context "repo" do
    let(:gwt) { instance_double('GitWorktree') }
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

    it "init" do
      expect(GitWorktree).to receive(:new).with(anything).and_return(gwt)
      expect(gwt).to receive(:branches).with(anything).and_return(branch_list)
      expect(gwt).to receive(:tags).with(no_args).and_return(tag_list)
      allow(gwt).to receive(:branch_info) do |name|
        branch_info_hash[name]
      end
      allow(gwt).to receive(:tag_info) do |name|
        tag_info_hash[name]
      end

      repo = FactoryGirl.create(:git_repository,
                                :dirname => File.join(Dir.tmpdir, "junk"),
                                :url     => "http://www.nonexistent.com/manageiq")
      expect(repo).to receive(:init_repo).with(no_args).and_call_original

      repo.refresh
      expect(repo.git_branches.collect(&:name)).to match_array(branch_list)
      expect(repo.git_tags.collect(&:name)).to match_array(tag_list)
    end

    it "update" do
      expect(GitWorktree).to receive(:new).with(anything).and_return(gwt)
      expect(gwt).to receive(:branches).with(anything).and_return(branch_list)
      expect(gwt).to receive(:tags).with(no_args).and_return(tag_list)
      expect(gwt).to receive(:fetch_and_merge).with(no_args).and_return({})
      allow(gwt).to receive(:branch_info) do |name|
        branch_info_hash[name]
      end
      allow(gwt).to receive(:tag_info) do |name|
        tag_info_hash[name]
      end

      repo = FactoryGirl.create(:git_repository,
                                :dirname => Dir.tmpdir,
                                :url     => "http://www.nonexistent.com/manageiq")
      expect(repo).to receive(:update_repo).with(no_args).and_call_original

      repo.refresh
      expect(repo.git_branches.collect(&:name)).to match_array(branch_list)
      expect(repo.git_tags.collect(&:name)).to match_array(tag_list)
    end

    it "branch info" do
      expect(GitWorktree).to receive(:new).with(anything).and_return(gwt)
      expect(gwt).to receive(:branches).with(anything).and_return(branch_list)
      expect(gwt).to receive(:tags).with(no_args).and_return(tag_list)
      allow(gwt).to receive(:branch_info) do |name|
        branch_info_hash[name]
      end
      allow(gwt).to receive(:tag_info) do |name|
        tag_info_hash[name]
      end

      repo = FactoryGirl.create(:git_repository,
                                :dirname => File.join(Dir.tmpdir, "junk"),
                                :url     => "http://www.nonexistent.com/manageiq")
      attrs = repo.branch_info('b1')
      expect(attrs['commit_sha']).to eq(info[:commit_sha])
    end

    it "tag info" do
      expect(GitWorktree).to receive(:new).with(anything).and_return(gwt)
      expect(gwt).to receive(:branches).with(anything).and_return(branch_list)
      expect(gwt).to receive(:tags).with(no_args).and_return(tag_list)
      allow(gwt).to receive(:branch_info) do |name|
        branch_info_hash[name]
      end
      allow(gwt).to receive(:tag_info) do |name|
        tag_info_hash[name]
      end

      repo = FactoryGirl.create(:git_repository,
                                :dirname => File.join(Dir.tmpdir, "junk"),
                                :url     => "http://www.nonexistent.com/manageiq")

      attrs = repo.tag_info('t1')
      expect(attrs['commit_sha']).to eq(tag_info_hash['t1'][:commit_sha])
    end

    it "missing tag" do
      expect(GitWorktree).to receive(:new).with(anything).and_return(gwt)
      expect(gwt).to receive(:branches).with(anything).and_return(branch_list)
      expect(gwt).to receive(:tags).with(no_args).and_return(tag_list)
      allow(gwt).to receive(:branch_info) do |name|
        branch_info_hash[name]
      end
      allow(gwt).to receive(:tag_info) do |name|
        tag_info_hash[name]
      end

      repo = FactoryGirl.create(:git_repository,
                                :dirname => File.join(Dir.tmpdir, "junk"),
                                :url     => "http://www.nonexistent.com/manageiq")
      expect { repo.tag_info('nothing') }.to raise_error(RuntimeError)
    end

    it "missing branch" do
      expect(GitWorktree).to receive(:new).with(anything).and_return(gwt)
      expect(gwt).to receive(:branches).with(anything).and_return(branch_list)
      expect(gwt).to receive(:tags).with(no_args).and_return(tag_list)
      allow(gwt).to receive(:branch_info) do |name|
        branch_info_hash[name]
      end
      allow(gwt).to receive(:tag_info) do |name|
        tag_info_hash[name]
      end

      repo = FactoryGirl.create(:git_repository,
                                :dirname => File.join(Dir.tmpdir, "junk"),
                                :url     => "http://www.nonexistent.com/manageiq")
      expect { repo.branch_info('nothing') }.to raise_error(RuntimeError)
    end
  end
end
