require 'spec_helper'

describe GitRepository do
  it "no url" do
    expect { FactoryGirl.create(:git_repository, :dirname => "abc") }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "invalid url" do
    expect { FactoryGirl.create(:git_repository, :url => "abc") }.to raise_error(ActiveRecord::RecordInvalid)
  end

  it "branches stored as an array" do
    repo = FactoryGirl.create(:git_repository_with_authentication,
                              :url => "http://www.github.com/manageiq",
                              :branches => %w(b1 b2 b3), :tags => %w(t1 t2 t3))
    expect(repo.branches).to match_array(%w(b1 b2 b3))
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

    it "init" do
      expect(GitWorktree).to receive(:new).with(anything).and_return(gwt)
      expect(gwt).to receive(:branches).with(anything).and_return(branch_list)
      expect(gwt).to receive(:tags).with(no_args).and_return(tag_list)

      repo = FactoryGirl.create(:git_repository,
                                :dirname => File.join(Dir.tmpdir, "junk"),
                                :url     => "http://www.nonexistent.com/manageiq")
      expect(repo).to receive(:init_repo).with(no_args).and_call_original

      repo.refresh
      expect(repo.branches).to match_array(branch_list)
      expect(repo.tags).to match_array(tag_list)
    end

    it "update" do
      expect(GitWorktree).to receive(:new).with(anything).and_return(gwt)
      expect(gwt).to receive(:branches).with(anything).and_return(branch_list)
      expect(gwt).to receive(:tags).with(no_args).and_return(tag_list)
      expect(gwt).to receive(:fetch_and_merge).with(no_args).and_return({})

      repo = FactoryGirl.create(:git_repository,
                                :dirname => Dir.tmpdir,
                                :url     => "http://www.nonexistent.com/manageiq")
      expect(repo).to receive(:update_repo).with(no_args).and_call_original

      repo.refresh
      expect(repo.branches).to match_array(branch_list)
      expect(repo.tags).to match_array(tag_list)
    end

    it "branch info" do
      expect(GitWorktree).to receive(:new).with(anything).and_return(gwt)
      expect(gwt).to receive(:branches).with(anything).and_return(branch_list)
      expect(gwt).to receive(:tags).with(no_args).and_return(tag_list)
      expect(gwt).to receive(:branch_info).with('b1').and_return(info)

      repo = FactoryGirl.create(:git_repository,
                                :dirname => File.join(Dir.tmpdir, "junk"),
                                :url     => "http://www.nonexistent.com/manageiq")

      expect(repo.branch_info('b1')).to have_attributes(info)
    end

    it "tag info" do
      expect(GitWorktree).to receive(:new).with(anything).and_return(gwt)
      expect(gwt).to receive(:branches).with(anything).and_return(branch_list)
      expect(gwt).to receive(:tags).with(no_args).and_return(tag_list)
      expect(gwt).to receive(:tag_info).with('t1').and_return(info)

      repo = FactoryGirl.create(:git_repository,
                                :dirname => File.join(Dir.tmpdir, "junk"),
                                :url     => "http://www.nonexistent.com/manageiq")

      expect(repo.tag_info('t1')).to have_attributes(info)
    end
  end
end
