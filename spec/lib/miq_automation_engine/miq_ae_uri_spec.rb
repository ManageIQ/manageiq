require "spec_helper"

module MiqAeUriSpec
  include MiqAeEngine
  describe MiqAeUri do

    it "converts hash queries" do
      env = 'dev'
      {
        "environment=#{env}&message=get_container_info&request=UI_PROVISION_INFO"   => { 'request' => 'UI_PROVISION_INFO', 'message' => 'get_container_info',  'environment' => env },
        "environment=#{env}&message=get_allowed_num_vms&request=UI_PROVISION_INFO"  => { 'request' => 'UI_PROVISION_INFO', 'message' => 'get_allowed_num_vms', 'environment' => env },
        "message=get_lease_times&request=UI_PROVISION_INFO"                         => { 'request' => 'UI_PROVISION_INFO', 'message' => 'get_lease_times' },
        "message=get_ttl_warnings&request=UI_PROVISION_INFO"                        => { 'request' => 'UI_PROVISION_INFO', 'message' => 'get_ttl_warnings' },
        "message=get_networks&request=UI_PROVISION_INFO"                            => { 'request' => 'UI_PROVISION_INFO', 'message' => 'get_networks' },
        "message=get_domains&request=UI_PROVISION_INFO"                             => { 'request' => 'UI_PROVISION_INFO', 'message' => 'get_domains' },
        "message=get_vmname&request=UI_PROVISION_INFO"                              => { 'request' => 'UI_PROVISION_INFO', 'message' => 'get_vmname' },
        "message=get_dialogs&request=UI_PROVISION_INFO"                             => { 'request' => 'UI_PROVISION_INFO', 'message' => 'get_dialogs' },
      }.each { |query, hash|
        MiqAeUri.hash2query(hash).should  == query
        MiqAeUri.query2hash(query).should == hash
      }
    end

    it "escape non-ASCII Numeric characters" do
      hash = {"test://dev?lab$~" => "OU=serverbuildingtest, OU=dev2"}
      query = MiqAeUri.hash2query(hash)
      query.should == "test%3A%2F%2Fdev%3Flab%24%7E=OU%3Dserverbuildingtest%2C%20OU%3Ddev2"

      result_hash = MiqAeUri.query2hash(query)
      result_hash.should == hash
    end

  end
end
