RSpec.describe FileDepotFtp do
  before do
    _, @miq_server, @zone = EvmSpecHelper.create_guid_miq_server_zone
  end

  let(:connection)     { double("FtpConnection") }
  let(:uri)            { "ftp://server.example.com/uploads" }
  let(:file_depot_ftp) { FileDepotFtp.new(:uri => uri) }
  let(:ftp_mock) do
    Class.new do
      attr_reader :pwd, :content
      def initialize(content = {})
        @pwd = '/'
        @content = content
      end

      def chdir(dir)
        newpath = (Pathname.new(pwd) + dir).to_s
        if local(newpath).kind_of? Hash
          @pwd = newpath
        end
      end

      private

      def local(path)
        local = @content
        path.split('/').each do |dir|
          next if dir.empty?
          local = local[dir]
          raise Net::FTPPermError, '550 Failed to change directory.' if local.nil?
        end
        local
      end
    end
  end

  let(:vsftpd_mock) do
    Class.new(ftp_mock) do
      def nlst(path = '')
        l = local(pwd + path)
        l.respond_to?(:keys) ? l.keys : []
      rescue
        return []
      end

      def mkdir(dir)
        l = local(pwd)
        l[dir] = {}
      end

      def putbinaryfile(local_path, remote_path)
        dir, base = Pathname.new(remote_path).split
        l = local(dir.to_s)
        l[base.to_s] = local_path
      end
    end
  end

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

  context "#merged_uri" do
    before do
      file_depot_ftp.uri = uri
    end

    it "should ignore the uri attribute from the file depot object and return the parameter" do
      expect(file_depot_ftp.merged_uri(nil, nil)).to eq nil
    end
  end
end
