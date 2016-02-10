describe RequestRefererService do
  let(:request_referer_service) { described_class.new }

  let(:controller_name) { 'host' }
  let(:action_name)     { 'show' }
  let(:dissallowed_controller_name) { 'foo' }
  let(:dissallowed_action_name)     { 'bar' }

  let(:controller_name_no_params) { 'vm_infra' }
  let(:action_name_no_params)     { 'explorer' }

  let(:get_request)          { double(:request_method => 'GET',  :parameters => {'id' => 1}, :xml_http_request? => false) }
  let(:post_request)         { double(:request_method => 'POST', :parameters => {'id' => 1}, :xml_http_request? => false) }
  let(:get_request_no_id)    { double(:request_method => 'GET',  :parameters => {},          :xml_http_request? => false) }
  let(:get_request_xml_http) { double(:request_method => 'GET',  :parameters => {'id' => 1}, :xml_http_request? => true)  }

  describe "#allowed_access?" do
    let(:req) { ActionDispatch::Request.new Rack::MockRequest.env_for '/?controller=dashboard' }

    describe "when the referer is external but trusted" do
      it "returns true" do
        expect(request_referer_service.allowed_access?(req, "dashboard", "show", "/external_idp", true)).to be_truthy
      end
    end

    describe "when the referer is external but not-trusted" do
      it "returns false" do
        expect(request_referer_service.allowed_access?(req, "dashboard", "show", "/external_idp")).to be_falsey
      end
    end
  end

  describe "#referer_valid?" do
    let(:referer)    { "PotatoHead" }
    let(:useragent)  { {"HTTP_USER_AGENT" => "Tater"} }
    let(:controller) { "DarthTater" }
    let(:action)     { "SpuddaFett" }

    describe "when the referer starts with the given string" do
      let(:string_to_test) { "Potato" }

      it "returns true" do
        expect(request_referer_service.referer_valid?(referer, string_to_test, useragent, controller, action)).to be_truthy
      end
    end

    describe "when the referer does not start with the given string" do
      let(:string_to_test) { "Tomato" }

      it "returns false" do
        expect(request_referer_service.referer_valid?(referer, string_to_test, useragent, controller, action)).to be_falsey
      end

      describe "when the controller and action are on the IE8 exception list" do
        let(:string_to_test) { "Tomato" }
        let(:useragent)      { {"HTTP_USER_AGENT" => "MSIE 8"} }
        let(:controller)     { "availability_zone" }
        let(:action)         { "download_data" }

        it "returns true" do
          expect(request_referer_service.referer_valid?(referer, string_to_test, useragent, controller, action)).to be_truthy
        end
      end

      describe "when the controller and action are not on the IE8 exception list" do
        let(:string_to_test) { "Tomato" }
        let(:useragent)      { {"HTTP_USER_AGENT" => "MSIE 8"} }
        let(:controller)     { "DarthTater" }
        let(:action)         { "SpuddaFett" }

        it "returns false" do
          expect(request_referer_service.referer_valid?(referer, string_to_test, useragent, controller, action)).to be_falsey
        end
      end
    end
  end

  describe '#access_whitelisted?' do
    it "allows only GET" do
      expect(request_referer_service.access_whitelisted?(get_request,   controller_name, action_name)).to be_truthy
      expect(request_referer_service.access_whitelisted?(post_request,  controller_name, action_name)).to be_falsey
    end

    it "allows only whitelistet entry points" do
      expect(request_referer_service.access_whitelisted?(get_request, controller_name, dissallowed_action_name)).to be_falsey
      expect(request_referer_service.access_whitelisted?(get_request, dissallowed_controller_name, action_name)).to be_falsey
    end

    it "requires an 'id' when specified" do
      expect(request_referer_service.access_whitelisted?(get_request_no_id, controller_name, action_name)).to be_falsey
    end

    it "requires no params, where none specified" do
      expect(request_referer_service.access_whitelisted?(get_request_no_id, controller_name_no_params, action_name_no_params)).to be_truthy
    end

    it "disallows xml_http requests" do
      expect(request_referer_service.access_whitelisted?(get_request_xml_http, controller_name, action_name)).to be_falsey
    end
  end
end
