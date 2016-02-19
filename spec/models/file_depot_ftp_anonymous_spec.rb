describe FileDepotFtpAnonymous do
  before :each do
    @ftpAnonymous = FileDepotFtpAnonymous.new
  end


  it "should require credentials with account anonymous" do
    expect(FileDepotFtpAnonymous.requires_credentials?).to eq true
    ss = FileDepotFtpAnonymous.new.login_credentials
    expect(ss[0]).to eq "anonymous"
  end

end
