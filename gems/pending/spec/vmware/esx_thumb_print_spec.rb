require "spec_helper"
require 'vmware/esx_thumb_print'
require 'vmware/vcenter_thumb_print'

describe ESXThumbPrint do
  HOST                     = "localhost"
  USER                     = "user"
  PASSWORD                 = "password"
  ESX_THUMB_PRINT_DATA_DIR = File.expand_path(File.join(File.dirname(__FILE__), 'data'))
  CERT                     = File.read(File.join(ESX_THUMB_PRINT_DATA_DIR, "esx_thumb_print.cer"))
  SHA1                     = File.read(File.join(ESX_THUMB_PRINT_DATA_DIR, "esx_thumb_print.sha1"))

  before(:each) do
    @tp = ESXThumbPrint.new(HOST, USER, PASSWORD)
  end

  it ".new" do
    @tp.user.should == USER
    @tp.host.should == HOST
    @tp.password.should == PASSWORD
    @tp.should be_kind_of(ESXThumbPrint)
    @tp.should_not be_kind_of(VcenterThumbPrint)
    @tp.should be_kind_of(ThumbPrint)
  end

  it ".new_http_request" do
    req = @tp.http_request
    req.should be_kind_of(Net::HTTP::Get)
    @tp.http.verify_mode.should == OpenSSL::SSL::VERIFY_NONE
  end

  it ".new_uri" do
    uri = @tp.uri
    uri.should be_kind_of(URI::HTTPS)
    uri.host.should be_kind_of(String)
    uri.host.should == HOST
    uri.port.should be_kind_of(Integer)
    uri.port.should == 443
  end

  it ".generates_a_sha1" do
    @tp.cert = CERT
    sha1 = @tp.to_sha1
    sha1.should be_kind_of(String)
    sha1.should == SHA1
  end
end
