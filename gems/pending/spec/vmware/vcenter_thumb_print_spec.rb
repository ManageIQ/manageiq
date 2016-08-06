require_relative '../../vmware/vcenter_thumb_print'
require_relative '../../vmware/esx_thumb_print'

describe VcenterThumbPrint do
  VCHOST = "localhost"

  before(:each) do
    @tp = VcenterThumbPrint.new(VCHOST)
  end

  it ".new" do
    expect(@tp.host).to eq(VCHOST)
    expect(@tp).to be_kind_of(VcenterThumbPrint)
    expect(@tp).not_to be_kind_of(ESXThumbPrint)
    expect(@tp).to be_kind_of(ThumbPrint)
  end

  it ".new_http_object" do
    http = @tp.http
    expect(http).to be_kind_of(Net::HTTP)
    expect(@tp.http.verify_mode).to eq(OpenSSL::SSL::VERIFY_NONE)
  end

  it ".new_uri" do
    uri = @tp.uri
    expect(uri).to be_kind_of(URI::HTTPS)
    expect(uri.host).to be_kind_of(String)
    expect(uri.host).to eq(VCHOST)
    expect(uri.port).to be_kind_of(Integer)
    expect(uri.port).to eq(443)
  end
end
