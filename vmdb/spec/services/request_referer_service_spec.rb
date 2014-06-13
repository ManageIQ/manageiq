require "spec_helper"

describe RequestRefererService do
  let(:request_referer_service) { described_class.new }

  let(:controller_name) { 'host' }
  let(:action_name)     { 'show' }
  let(:dissallowed_controller_name) { 'foo' }
  let(:dissallowed_action_name)     { 'bar' }

  let(:controller_name_no_params) { 'vm_infra' }
  let(:action_name_no_params)     { 'explorer' }

  let(:get_request)          { stub(:request_method => 'GET',  :parameters => {'id' => 1}, :xml_http_request? => false) }
  let(:post_request)         { stub(:request_method => 'POST', :parameters => {'id' => 1}, :xml_http_request? => false) }
  let(:get_request_no_id)    { stub(:request_method => 'GET',  :parameters => {},          :xml_http_request? => false) }
  let(:get_request_xml_http) { stub(:request_method => 'GET',  :parameters => {'id' => 1}, :xml_http_request? => true)  }

  describe "#referer_valid?" do
    let(:referer) { "PotatoHead" }

    describe "when the referer starts with the given string" do
      let(:string_to_test) { "Potato" }

      it "returns true" do
        request_referer_service.referer_valid?(referer, string_to_test).should be_true
      end
    end

    describe "when the referer does not start with the given string" do
      let(:string_to_test) { "Tomato" }

      it "returns false" do
        request_referer_service.referer_valid?(referer, string_to_test).should be_false
      end
    end
  end

  describe '#access_whitelisted?' do

    it "allows only GET" do
      request_referer_service.access_whitelisted?(get_request,   controller_name, action_name).should be_true
      request_referer_service.access_whitelisted?(post_request,  controller_name, action_name).should be_false
    end

    it "allows only whitelistet entry points" do
      request_referer_service.access_whitelisted?(get_request, controller_name, dissallowed_action_name).should be_false
      request_referer_service.access_whitelisted?(get_request, dissallowed_controller_name, action_name).should be_false
    end

    it "requires an 'id' when specified" do
      request_referer_service.access_whitelisted?(get_request_no_id, controller_name, action_name).should be_false
    end

    it "requires no params, where none specified" do
      request_referer_service.access_whitelisted?(get_request_no_id, controller_name_no_params, action_name_no_params).should be_true
    end

    it "disallows xml_http requests" do
      request_referer_service.access_whitelisted?(get_request_xml_http, controller_name, action_name).should be_false
    end
  end
end
