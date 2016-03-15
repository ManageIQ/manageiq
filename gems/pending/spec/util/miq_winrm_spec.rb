require 'util/miq_winrm'

describe MiqWinRM do
  before(:each) do
    @host     = "localhost"
    @user     = "user"
    @password = "password"
    @winrm    = MiqWinRM.new
  end

  context "New Object" do
    it "has a nil executor" do
      expect(@winrm.executor).to be_nil
    end
  end

  context "New Connection" do
    it "creates a network connection" do
      expect { @winrm.connect(:user => @user, :pass => @password, :hostname => @host) }.to_not raise_error
    end
  end

  context "Existing Connection Attributes" do
    before(:each) do
      @connection = @winrm.connect(:user => @user, :pass => @password, :hostname => @host)
    end

    it "is the correct WinRM class" do
      expect(@connection).to be_a(WinRM::WinRMWebService)
    end

    it "still has a nil executor" do
      expect(@winrm.executor).to be_nil
    end

    it "has the correct attributes" do
      expect(@winrm.username).to eq(@user)
      expect(@winrm.password).to eq(@password)
      expect(@winrm.hostname).to eq(@host)
      expect(@winrm.port).to eq(5985)
    end
  end

  context "New Elevated Runner" do
    before(:each) do
      @connection = @winrm.connect(:user => @user, :pass => @password, :hostname => @host)
    end

    it "Creates an Elevated Runner successfully" do
      expect { @winrm.elevate }.to_not raise_error
      expect(@winrm.elevate).to be_a(WinRM::Elevated::Runner)
    end
  end
end
