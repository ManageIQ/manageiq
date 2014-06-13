require "spec_helper"

describe Repository do

  it "is not valid with empty attributes" do
    repo = Repository.new
    repo.should_not be_valid
    repo.errors.should include(:name)
    repo.errors.should include(:relative_path)
  end

  it "is not valid with duplicate name" do
    nas_relative_path  = "//hostname/share/directory"
    nas_name           = "nas_repo"

    vmfs_relative_path = "[Storage]directory/directory"
    vmfs_name          = "vmfs_repo"

    nas  = FactoryGirl.create(:repository, :name => nas_name,  :relative_path => nas_relative_path)
    vmfs = FactoryGirl.create(:repository, :name => vmfs_name, :relative_path => vmfs_relative_path)

    repo = Repository.new(:name => nas_name, :relative_path => nas_relative_path)
    repo.save.should_not be_true
    repo.errors[:name].should == ["has already been taken"]
  end

  it "#valid_path class method works properly" do
    good = [
      '//hostname/share/directory/valid',
      '\\\hostname\share\directory\valid',
      '//hostname\share/directory\valid'
    ]
    bad = [
      '/hostname/share/directory/valid',
      '\hostname\share\directory\valid',
      'c:\program files\myrepo'
    ]
    good.each { |path| Repository.should     be_valid_path(path) }
    bad.each  { |path| Repository.should_not be_valid_path(path) }
  end

  it "is creates needed storage" do
    sname   = "//myserver/myshare"
    relpath = "mydir"
    repo = Repository.add("test_storage_created", File.join(sname, relpath))

    repo.storage.should_not be_nil
    repo.storage.name.should  == sname
    repo.relative_path.should == relpath
  end
end
