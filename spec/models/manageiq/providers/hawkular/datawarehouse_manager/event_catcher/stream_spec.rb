describe ManageIQ::Providers::Hawkular::DatawarehouseManager::EventCatcher::Stream do
  subject do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    auth                 = AuthToken.new(:auth_key => "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJtYW5hZ2VtZW50LWluZnJhIiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6Im1hbmFnZW1lbnQtYWRtaW4tdG9rZW4tdmtlN2siLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC5uYW1lIjoibWFuYWdlbWVudC1hZG1pbiIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50LnVpZCI6Ijg3MDQ5NzNjLWRiMjMtMTFlNi05NDlkLTAwMWE0YTE2MjY3YyIsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDptYW5hZ2VtZW50LWluZnJhOm1hbmFnZW1lbnQtYWRtaW4ifQ.nuNCehi01GT7sbGGliCjTdwzZjNo4mjsbgGwuyChCxZJhj2Jyb7C2ZUABfgh26g466EReMal5M4F7Nbah_cbZgfrWi1NK0h_f18g8kA_m3jn9CfbfajZAGSMEUrVwHx05IqVqEI4FMJM5XwYBP8pTSEGjYcuk5OOSEK_xXs-Lt_iJYaOUMjWNa-XnI3zjiD5f7eP-FBOek2-YtFlcSJt3lqQyM_fjrocnMF9B3JWYcFLQ-ctuRaOHvaK-eaXz1AzFctBfaBGYXSw0LrH0slWqNC0Fu1AWpKKvwrOwD70DhUgjBGnD3Va_3ewTe5KNwByib6ox6xOQVYnfg7SoSOdCg",
                                         :userid   => "_")
    ems                  = FactoryGirl.create(:ems_hawkular_datawarehouse,
                                              :hostname        => 'metrics.10.35.48.125.xip.io',
                                              :port            => 443,
                                              :authentications => [auth],
                                              :zone            => zone)
    described_class.new(ems)
  end

  context "#fetch" do
    it "yields valid events" do
      VCR.use_cassette(
        described_class.name.underscore.to_s,
        :decode_compressed_response => true,
        # :record                   => :new_episodes,
      ) do
        result = subject.instance_eval('fetch')
        expect(result.count).to be == 1
        expect(result.first[:text]).to eq "This text shows up on the alert"
        expect(result.first[:tags]).to include(
          "nodename" => "vm-48-124.eng.lab.tlv.redhat.com",
          "type"     => "node",
          "url"      => "https://www.youtube.com/watch?v=dQw4w9WgXcQ"
        )
        expect(result.first[:severity]).to eq "HIGH"
      end
    end
  end
end
