require 'util/miq_ftp_lib'
require 'logger' # probably loaded elsewhere, but for the below classes

class FTPKlass
  include MiqFtpLib

  attr_accessor :uri

  def self.instance_logger
    Logger.new(File::NULL) # null logger (for testing)
  end

  private

  def _log
    self.class.instance_logger
  end
end

class OtherFTPKlass
  include MiqFtpLib

  attr_accessor :uri

  def _log
    private_log_method
  end

  private

  def private_log_method
    Logger.new(File::NULL) # null logger (for testing)
  end

  def login_credentials
    %w(ftpuser ftppass)
  end
end

shared_examples "connecting" do |valid_cred_hash|
  let(:cred_hash) { valid_cred_hash }

  before { subject.uri = "ftp://localhost" }

  it "logs in with valid credentials" do
    expect { subject.connect(cred_hash) }.not_to raise_error
  end

  it "sets the connection to passive" do
    subject.connect(cred_hash)
    expect(subject.ftp.passive).to eq(true)
  end

  context "with an invalid ftp credentials" do
    let(:cred_hash) { { :username => "invalid", :password => "alsoinvalid" } }

    it "raises a Net::FTPPermError" do
      expect { subject.connect(cred_hash) }.to raise_error(Net::FTPPermError)
    end
  end
end

shared_examples "with a connection" do |valid_cred_hash|
  let(:cred_hash) { valid_cred_hash }
  let(:error_msg) { "no block given" }

  before do
    subject.uri = "ftp://localhost"
    allow(subject).to receive(:_).with(error_msg).and_return(error_msg)
  end

  def with_connection(&block)
    subject.send(:with_connection, cred_hash, &block)
  end

  def get_socket(ftp)
    ftp.instance_variable_get(:@sock).instance_variable_get(:@io)
  end

  it "passes the ftp object to the block" do
    with_connection do |ftp|
      expect(ftp).to         be_a(Net::FTP)
      expect(subject.ftp).to be(ftp)
    end
  end

  it "closes the ftp connection after the block is finished" do
    ftp_instance = subject.connect(cred_hash)
    # stub further calls to `#connect`
    expect(subject).to receive(:connect).and_return(ftp_instance)

    with_connection { |ftp| }
    expect(subject.ftp).to          eq(nil)
    expect(ftp_instance.closed?).to eq(true)
  end

  it "raises an error if no block is given" do
    expect { with_connection }.to raise_error(RuntimeError, error_msg)
  end
end

describe MiqFtpLib do
  subject { FTPKlass.new }

  describe "when included" do
    it "has a `ftp` accessor" do
      ftp_instance = Net::FTP.new
      subject.ftp  = ftp_instance

      expect(subject.ftp).to eq ftp_instance
    end
  end

  describe "#connect", :with_ftp_server do
    context "with credentials hash" do
      subject { FTPKlass.new }

      include_examples "connecting", :username => "ftpuser", :password => "ftppass"
    end

    context "with login_credentials method" do
      subject { OtherFTPKlass.new }

      include_examples "connecting"
    end
  end

  describe "#with_connection", :with_ftp_server do
    context "with credentials hash" do
      subject { FTPKlass.new }

      include_examples "with a connection", :username => "ftpuser", :password => "ftppass"
    end

    context "with login_credentials method" do
      subject { OtherFTPKlass.new }

      include_examples "with a connection"
    end
  end

  describe "#file_exists?", :with_ftp_server do
    let(:existing_file) { File.basename(existing_ftp_file) }

    subject             { FTPKlass.new.tap { |ftp| ftp.uri = "ftp://localhost" } }
    before              { subject.connect(valid_ftp_creds) }

    it "returns true if the file exists" do
      expect(subject.file_exists?(existing_file)).to eq(true)
    end

    it "returns false if the file does not exist" do
      expect(subject.file_exists?("#{existing_file}.fake")).to eq(false)
    end
  end

  # Note:  Don't use `file_exists?` to try and test the directory existance.
  # Most FTP implementations will send the results of `nlst` as the contents of
  # a directory if a directory is given.
  #
  # In our current implementation, this will return a empty list if the
  # directory is empty, thus causing the check to fail.  Testing against the
  # `ftp.nlst(parent_dir)` will make sure the directory in question is included
  # in it's parent.
  describe "#create_directory_structure", :with_ftp_server do
    subject             { OtherFTPKlass.new.tap { |ftp| ftp.uri = "ftp://localhost" } }
    before              { subject.connect(valid_ftp_creds) }

    it "creates a new nested directory" do
      new_dir    = "foo/bar/baz"
      parent_dir = File.dirname(new_dir)

      expect(subject.ftp.nlst(parent_dir).include?("baz")).to eq(false)
      subject.send(:create_directory_structure, new_dir)
      expect(subject.ftp.nlst(parent_dir).include?("baz")).to eq(true)
    end

    context "to an existing directory" do
      it "creates the nested directory without messing with the existing" do
        existing_dir = existing_ftp_dir
        new_dir      = File.join(existing_ftp_dir, "foo/bar/baz")
        parent_dir   = File.dirname(new_dir)

        expect(subject.ftp.nlst.include?(existing_dir)).to      eq(true)
        expect(subject.ftp.nlst(parent_dir).include?("baz")).to eq(false)

        subject.send(:create_directory_structure, new_dir)
        expect(subject.ftp.nlst.include?(existing_dir)).to      eq(true)
        expect(subject.ftp.nlst(parent_dir).include?("baz")).to eq(true)
      end
    end
  end
end
