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
    expect(@tp.user).to eq(USER)
    expect(@tp.host).to eq(HOST)
    expect(@tp.password).to eq(PASSWORD)
    expect(@tp).to be_kind_of(ESXThumbPrint)
    expect(@tp).not_to be_kind_of(VcenterThumbPrint)
    expect(@tp).to be_kind_of(ThumbPrint)
  end

  it ".new_http_request" do
    req = @tp.http_request
    expect(req).to be_kind_of(Net::HTTP::Get)
    expect(@tp.http.verify_mode).to eq(OpenSSL::SSL::VERIFY_NONE)
  end

  it ".new_uri" do
    uri = @tp.uri
    expect(uri).to be_kind_of(URI::HTTPS)
    expect(uri.host).to be_kind_of(String)
    expect(uri.host).to eq(HOST)
    expect(uri.port).to be_kind_of(Integer)
    expect(uri.port).to eq(443)
  end

  it ".generates_a_sha1" do
    @tp.cert = CERT
    sha1 = @tp.to_sha1
    expect(sha1).to be_kind_of(String)
    expect(sha1).to eq(SHA1)
  end
end
