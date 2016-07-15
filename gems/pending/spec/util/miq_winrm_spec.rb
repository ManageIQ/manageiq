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
      expect { @winrm.connect(:user => @user, :password => @password, :hostname => @host) }.to_not raise_error
    end
  end

  context "Existing Connection Attributes" do
    before(:each) do
      @connection = @winrm.connect(:user => @user, :password => @password, :hostname => @host)
    end

    it "is the correct WinRM class" do
      expect(@connection).to be_a(WinRM::Connection)
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

  context "XML Parsing" do
    let(:xml) do
      "#< CLIXML\r\n<Objs Version=\"1.1.0.1\" xmlns=\"http://schemas.microsoft.com/powershell/2004/04\"><S S=\"Error\">Bogus : The term 'Bogus' is not recognized as the name of a cmdlet, function, _x000D__x000A_</S><S S=\"Error\">script file, or operable program. Check the spelling of the name, or if a path _x000D__x000A_</S><S S=\"Error\">was included, verify that the path is correct and try again._x000D__x000A_</S><S S=\"Error\">At line:1 char:40_x000D__x000A_</S><S S=\"Error\">+ $ProgressPreference='SilentlyContinue';Bogus_x000D__x000A_</S><S S=\"Error\">+                                        ~~~~~_x000D__x000A_</S><S S=\"Error\">    + CategoryInfo          : ObjectNotFound: (Bogus:String) [], CommandNotFou _x000D__x000A_</S><S S=\"Error\">   ndException_x000D__x000A_</S><S S=\"Error\">    + FullyQualifiedErrorId : CommandNotFoundException_x000D__x000A_</S><S S=\"Error\"> _x000D__x000A_</S></Objs>"
    end

    it "defines a parse_xml_error_string method" do
      expect(@winrm).to respond_to(:parse_xml_error_string)
    end

    it "returns the expected string" do
      expected_string = "Bogus : The term 'Bogus' is not recognized as the name of a cmdlet, function, script file, or operable program. Check the spelling of the name, or if a path was included, verify that the path is correct and try again."
      expect(@winrm.parse_xml_error_string(xml)).to eql(expected_string)
    end
  end
end
