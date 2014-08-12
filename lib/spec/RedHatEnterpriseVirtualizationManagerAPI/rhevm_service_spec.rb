require 'spec_helper'
require 'rest-client'

$LOAD_PATH.push(File.expand_path(File.join(File.dirname(__FILE__), %w{.. .. RedHatEnterpriseVirtualizationManagerAPI})))
require 'rhevm_api'

describe RhevmService do
  before do
    @service = RhevmService.new(:server => "", :username => "", :password => "")
  end

  context "#resource_post" do
    it "raises RhevmApiError if HTTP 409 response code received" do
      error_detail = "API error"
      return_data = <<-EOX.chomp
<action>
    <fault>
        <detail>#{error_detail}</detail>
    </fault>
</action>
EOX

      rest_client = double('rest_client').as_null_object
      rest_client.should_receive(:post) do |&block|
        return_data.stub(:code).and_return(409)
        block.call(return_data)
      end

      @service.stub(:create_resource).and_return(rest_client)
      expect { @service.resource_post('uri', 'data') }.to raise_error(RhevmApiError, error_detail)
    end
  end
end
