RSpec.describe FileDepotFtpAnonymous do
  it "should require credentials for anonymous" do
    expect(FileDepotFtpAnonymous.requires_credentials?).to eq true
    expect(FileDepotFtpAnonymous.new.login_credentials[0]).to eq "anonymous"
  end
end
