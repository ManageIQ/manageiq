describe "proxy uri" do
  it "decodes the password" do
    uri = URI('proxy://myuser:%24%3fxxxx@192.168.122.40:3128')
    expect(uri.password).to eq('$?xxxx')
  end

  it "extracts the user" do
    uri = URI('proxy://myuser:%24%3fxxxx@192.168.122.40:3128')
    expect(uri.user).to eq('myuser')
  end

  it "extracts the host" do
    uri = URI('proxy://myuser:%24%3fxxxx@192.168.122.40:3128')
    expect(uri.host).to eq('192.168.122.40')
  end

  it "extracts the port" do
    uri = URI('proxy://myuser:%24%3fxxxx@192.168.122.40:3128')
    expect(uri.port).to eq(3128)
  end

  it "returns nil user and password if there is no userinfo" do
    uri = URI('proxy://192.168.122.40:3128')
    expect(uri.user).to be_nil
    expect(uri.password).to be_nil
  end

  it "returns nil password if there user but no password" do
    uri = URI('proxy://myuser@192.168.122.40:3128')
    expect(uri.user).to eq('myuser')
    expect(uri.password).to be_nil
  end

  it "decodes users that are e-mail addresses" do
    uri = URI('proxy://myuser%40example.com@192.168.122.40:3128')
    expect(uri.user).to eq('myuser@example.com')
  end
end
