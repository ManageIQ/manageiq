require_relative "../spec_helper"
require_relative '../../vmware/vcenter_thumb_print'
require_relative '../../vmware/esx_thumb_print'

describe VcenterThumbPrint do
  VCHOST = "localhost"

  before(:each) do
    @tp = VcenterThumbPrint.new(VCHOST)
  end

  it ".new" do
    @tp.host.should == VCHOST
    @tp.should be_kind_of(VcenterThumbPrint)
    @tp.should_not be_kind_of(ESXThumbPrint)
    @tp.should be_kind_of(ThumbPrint)
  end

  it ".new_http_object" do
    http = @tp.http
    http.should be_kind_of(Net::HTTP)
    @tp.http.verify_mode.should == OpenSSL::SSL::VERIFY_NONE
  end

  it ".new_uri" do
    uri = @tp.uri
    uri.should be_kind_of(URI::HTTPS)
    uri.host.should be_kind_of(String)
    uri.host.should == VCHOST
    uri.port.should be_kind_of(Integer)
    uri.port.should == 443
  end
end
