require "spec_helper"

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

      expect(file_depot_ftp.file_exists?("somefile")).to be_true
    end

    it "false if ftp raises on missing file" do
      file_depot_ftp.ftp = double
      file_depot_ftp.ftp.should_receive(:nlst).and_raise(Net::FTPPermError)

      expect(file_depot_ftp.file_exists?("somefile")).to be_false
    end

    it "false if file missing" do
      file_depot_ftp.ftp = double(:nlst => [])

      expect(file_depot_ftp.file_exists?("somefile")).to be_false
    end
  end

  context "#upload_file" do
    it "does not already exist" do
      file_depot_ftp.should_receive(:connect).and_return(connection)
      file_depot_ftp.should_receive(:file_exists?).exactly(4).times.and_return(false)
      connection.should_receive(:mkdir).with("uploads")
      connection.should_receive(:mkdir).with("uploads/#{@zone.name}_#{@zone.id}")
      connection.should_receive(:mkdir).with("uploads/#{@zone.name}_#{@zone.id}/#{@miq_server.name}_#{@miq_server.id}")
      connection.should_receive(:putbinaryfile)
      log_file.should_receive(:post_upload_tasks)
      connection.should_receive(:close)

      file_depot_ftp.upload_file(log_file)
    end

    it "already exists" do
      file_depot_ftp.should_receive(:connect).and_return(connection)
      file_depot_ftp.should_receive(:file_exists?).and_return(true)
      connection.should_not_receive(:mkdir)
      connection.should_not_receive(:putbinaryfile)
      log_file.should_not_receive(:post_upload_tasks)
      connection.should_receive(:close)

      file_depot_ftp.upload_file(log_file)
    end
  end
end
