describe MiqAeEngine::MiqAeUri do
  it "converts hash queries" do
    env = 'dev'
    {
      "environment=#{env}&message=get_container_info&request=UI_PROVISION_INFO"  => {'request' => 'UI_PROVISION_INFO', 'message' => 'get_container_info',  'environment' => env},
      "environment=#{env}&message=get_allowed_num_vms&request=UI_PROVISION_INFO" => {'request' => 'UI_PROVISION_INFO', 'message' => 'get_allowed_num_vms', 'environment' => env},
      "message=get_lease_times&request=UI_PROVISION_INFO"                        => {'request' => 'UI_PROVISION_INFO', 'message' => 'get_lease_times'},
      "message=get_ttl_warnings&request=UI_PROVISION_INFO"                       => {'request' => 'UI_PROVISION_INFO', 'message' => 'get_ttl_warnings'},
      "message=get_networks&request=UI_PROVISION_INFO"                           => {'request' => 'UI_PROVISION_INFO', 'message' => 'get_networks'},
      "message=get_vmname&request=UI_PROVISION_INFO"                             => {'request' => 'UI_PROVISION_INFO', 'message' => 'get_vmname'},
      "message=get_dialogs&request=UI_PROVISION_INFO"                            => {'request' => 'UI_PROVISION_INFO', 'message' => 'get_dialogs'},
    }.each do |query, hash|
      expect(described_class.hash2query(hash)).to eq(query)
      expect(described_class.query2hash(query)).to eq(hash)
    end
  end

  it "escape non-ASCII Numeric characters" do
    hash = {"test://dev?lab$~" => "OU=serverbuildingtest, OU=dev2"}
    query = described_class.hash2query(hash)
    expect(query).to eq("test%3A%2F%2Fdev%3Flab%24%7E=OU%3Dserverbuildingtest%2C%20OU%3Ddev2")

    result_hash = described_class.query2hash(query)
    expect(result_hash).to eq(hash)
  end

  it "trim URI before parsing" do
    uri = "/Cloud/VM/StateMachines/Sample  "
    _, _, _, _, _, path = described_class.split(uri)

    expect(path).to eq(uri.strip)
  end
end
