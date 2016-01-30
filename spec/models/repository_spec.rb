describe Repository do
  it "is not valid with empty attributes" do
    repo = Repository.new
    expect(repo).not_to be_valid
    expect(repo.errors).to include(:name)
    expect(repo.errors).to include(:relative_path)
  end

  it "is not valid with duplicate name" do
    nas_relative_path  = "//hostname/share/directory"
    nas_name           = "nas_repo"

    vmfs_relative_path = "[Storage]directory/directory"
    vmfs_name          = "vmfs_repo"

    nas  = FactoryGirl.create(:repository, :name => nas_name,  :relative_path => nas_relative_path)
    vmfs = FactoryGirl.create(:repository, :name => vmfs_name, :relative_path => vmfs_relative_path)

    repo = Repository.new(:name => nas_name, :relative_path => nas_relative_path)
    expect(repo.save).not_to be_truthy
    expect(repo.errors[:name]).to eq(["has already been taken"])
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
    good.each { |path| expect(Repository).to     be_valid_path(path) }
    bad.each  { |path| expect(Repository).not_to be_valid_path(path) }
  end

  it "is creates needed storage" do
    sname   = "//myserver/myshare"
    relpath = "mydir"
    repo = Repository.add("test_storage_created", File.join(sname, relpath))

    expect(repo.storage).not_to be_nil
    expect(repo.storage.name).to eq(sname)
    expect(repo.relative_path).to eq(relpath)
  end
end
