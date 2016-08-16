describe ManageIQ::Providers::Microsoft::InfraManager::Powershell do
  before(:all) do
    class PowershellTemp; end
  end

  before(:each) do
    @powershell = PowershellTemp.new
    @powershell.extend(ManageIQ::Providers::Microsoft::InfraManager::Powershell::ClassMethods)
  end

  let(:powershell) { @powershell }

  context "class methods" do
    it "defines expected methods" do
      expect(powershell).to respond_to(:execute_powershell)
      expect(powershell).to respond_to(:run_powershell_script)
      expect(powershell).to respond_to(:powershell_results_to_hash)
      expect(powershell).to respond_to(:powershell_xml_to_hash)
      expect(powershell).to respond_to(:log_dos_error_results)
      expect(powershell).to respond_to(:parse_json_results)
      expect(powershell).to respond_to(:decompress_results)
    end
  end

  context "log_dos_error_results" do
    let(:xml) do
      "#< CLIXML\r\n<Objs Version=\"1.1.0.1\" xmlns=\"http://schemas.microsoft.com/powershell/2004/04\"><S S=\"Error\">Bogus : The term 'Bogus' is not recognized as the name of a cmdlet, function, _x000D__x000A_</S><S S=\"Error\">script file, or operable program. Check the spelling of the name, or if a path _x000D__x000A_</S><S S=\"Error\">was included, verify that the path is correct and try again._x000D__x000A_</S><S S=\"Error\">At line:1 char:40_x000D__x000A_</S><S S=\"Error\">+ $ProgressPreference='SilentlyContinue';Bogus_x000D__x000A_</S><S S=\"Error\">+                                        ~~~~~_x000D__x000A_</S><S S=\"Error\">    + CategoryInfo          : ObjectNotFound: (Bogus:String) [], CommandNotFou _x000D__x000A_</S><S S=\"Error\">   ndException_x000D__x000A_</S><S S=\"Error\">    + FullyQualifiedErrorId : CommandNotFoundException_x000D__x000A_</S><S S=\"Error\"> _x000D__x000A_</S></Objs>"
    end

    before(:each) do
      $original_scvmm_log = $scvmm_log.clone
      @log_file = Rails.root.join("spec/tools/scvmm_data/powershell.log")
      $scvmm_log = Vmdb::Loggers::MirroredLogger.new(@log_file, "<POWERSHELL>")
    end

    after(:each) do
      $scvmm_log = $original_scvmm_log
      File.delete(@log_file) if File.exist?(@log_file)
    end

    it "returns true on success" do
      text = 'some error'
      expect(powershell.log_dos_error_results(text)).to eq(true)
    end

    it "sets the log header to the expected string" do
      powershell.log_dos_error_results('another error')
      first_line = $scvmm_log.contents.split("\n")[1]
      expect(first_line).to match('MIQ')
      expect(first_line).to match('log_dos_error_results')
      expect(first_line).to match('another error')
    end

    it "does not write empty strings to the log" do
      powershell.log_dos_error_results('')
      first_line = $scvmm_log.contents.split("\n")[1]
      expect(first_line).to be(nil)
    end

    it "parses XML into a readable string" do
      allow(xml).to receive(:stderr).and_return(xml)
      powershell.log_dos_error_results(xml)

      text = "Bogus : The term 'Bogus' is not recognized as the name of a "
      text << "cmdlet, function, script file, or operable program. Check the "
      text << "spelling of the name, or if a path was included, verify that "
      text << "the path is correct and try again."

      expect($scvmm_log.contents.include?(text)).to eql(true)
    end
  end

  context "decompress_results" do
    before(:all) do
      @xml_file = Rails.root.join("spec/tools/scvmm_data/get_inventory_output.xml")
      @xml = IO.read(@xml_file)
    end

    let(:xml) { @xml }

    it "handles compressed XML text" do
      zipped_text = Base64.encode64(ActiveSupport::Gzip.compress(xml))
      expect(powershell.decompress_results(zipped_text)).to be_kind_of(String)
      expect(powershell.decompress_results(zipped_text)).to eq(xml)
    end

    it "handles plain XML text" do
      plain_text = @xml
      expect(powershell.decompress_results(plain_text)).to be_kind_of(String)
      expect(powershell.decompress_results(plain_text)).to eq(xml)
    end
  end

  context "parse_json_results" do
    before(:all) do
      @yml_file = Rails.root.join("spec/tools/scvmm_data/get_inventory_output.yml")
      @json = JSON.dump(YAML.load(IO.read(@yml_file)))
    end

    let(:json) { @json }

    it "handles compressed yaml text" do
      zipped_text = Base64.encode64(ActiveSupport::Gzip.compress(json))
      expect(powershell.parse_json_results(zipped_text)).to be_kind_of(Array)
      expect(powershell.parse_json_results(zipped_text).first).to be_kind_of(Hash)
    end

    it "handles plain yaml text" do
      expect(powershell.parse_json_results(json)).to be_kind_of(Array)
      expect(powershell.parse_json_results(json).first).to be_kind_of(Hash)
    end
  end
end
