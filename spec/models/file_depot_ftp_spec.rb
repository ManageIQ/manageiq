describe FileDepotFtp do
  before do
    _, @miq_server, @zone = EvmSpecHelper.create_guid_miq_server_zone
  end

  let(:connection)     { double("FtpConnection") }
  let(:file_depot_ftp) { FileDepotFtp.new(:uri => "ftp://server.example.com/uploads") }
  let(:log_file)       { LogFile.new(:resource => @miq_server, :local_file => "/tmp/file.txt") }

  context "#file_exists?" do
    it "true if file exists" do
      file_depot_ftp.ftp = double(:nlst => ["somefile"])

      expect(file_depot_ftp.file_exists?("somefile")).to be_truthy
    end

    it "false if ftp raises on missing file" do
      file_depot_ftp.ftp = double
      expect(file_depot_ftp.ftp).to receive(:nlst).and_raise(Net::FTPPermError)

      expect(file_depot_ftp.file_exists?("somefile")).to be_falsey
    end

    it "false if file missing" do
      file_depot_ftp.ftp = double(:nlst => [])

      expect(file_depot_ftp.file_exists?("somefile")).to be_falsey
    end
  end

  context "#upload_file" do
    it "does not already exist" do
      expect(file_depot_ftp).to receive(:connect).and_return(connection)
      expect(file_depot_ftp).to receive(:file_exists?).exactly(4).times.and_return(false)
      expect(connection).to receive(:mkdir).with("uploads")
      expect(connection).to receive(:mkdir).with("uploads/#{@zone.name}_#{@zone.id}")
      expect(connection).to receive(:mkdir).with("uploads/#{@zone.name}_#{@zone.id}/#{@miq_server.name}_#{@miq_server.id}")
      expect(connection).to receive(:putbinaryfile)
      expect(log_file).to receive(:post_upload_tasks)
      expect(connection).to receive(:close)

      file_depot_ftp.upload_file(log_file)
    end

    it "already exists" do
      expect(file_depot_ftp).to receive(:connect).and_return(connection)
      expect(file_depot_ftp).to receive(:file_exists?).and_return(true)
      expect(connection).not_to receive(:mkdir)
      expect(connection).not_to receive(:putbinaryfile)
      expect(log_file).not_to receive(:post_upload_tasks)
      expect(connection).to receive(:close)

      file_depot_ftp.upload_file(log_file)
    end
  end
end
