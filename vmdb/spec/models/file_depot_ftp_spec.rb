require "spec_helper"

describe FileDepotFtp do
  before do
    _, @miq_server, _ = EvmSpecHelper.create_guid_miq_server_zone
  end

  let(:connection)     { double("FtpConnection") }
  let(:file_depot_ftp) { FileDepotFtp.new(:uri => "ftp://server.example.com/uploads") }
  let(:log_file)       { LogFile.new(:resource => @miq_server, :local_file => "/tmp/file.txt") }

  context "#upload_file" do
    it "does not already exist" do
      file_depot_ftp.should_receive(:connect).and_return(connection)
      file_depot_ftp.should_receive(:destination_file_exists?).and_return(false)
      connection.should_receive(:mkdir).with("/uploads/default_#{@miq_server.id}/miq_server_1_#{@miq_server.id}")
      connection.should_receive(:putbinaryfile)
      log_file.should_receive(:post_upload_tasks)
      connection.should_receive(:close)

      file_depot_ftp.upload_file(log_file)
    end

    it "already exists" do
      file_depot_ftp.should_receive(:connect).and_return(connection)
      file_depot_ftp.should_receive(:destination_file_exists?).and_return(true)
      connection.should_not_receive(:mkdir)
      connection.should_not_receive(:putbinaryfile)
      log_file.should_not_receive(:post_upload_tasks)
      connection.should_receive(:close)

      file_depot_ftp.upload_file(log_file)
    end
  end
end
