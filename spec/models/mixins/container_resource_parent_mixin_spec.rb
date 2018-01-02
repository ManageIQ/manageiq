describe ContainerResourceParentMixin do
  before(:each) do
    allow(MiqServer).to receive(:my_zone).and_return("default")
    hostname = 'host.example.com'
    token = 'theToken'

    @ems = FactoryGirl.create(
      :ems_openshift,
      :name                      => 'OpenShiftProvider',
      :connection_configurations => [{:endpoint       => {:role       => :default,
                                                          :hostname   => hostname,
                                                          :port       => "8443",
                                                          :verify_ssl => OpenSSL::SSL::VERIFY_NONE},
                                      :authentication => {:role     => :bearer,
                                                          :auth_key => token,
                                                          :userid   => "_"}},
                                     {:endpoint       => {:role     => :hawkular,
                                                          :hostname => hostname,
                                                          :port     => "443"},
                                      :authentication => {:role     => :hawkular,
                                                          :auth_key => token,
                                                          :userid   => "_"}}]
    )

    @test_project = FactoryGirl.create(:container_project, :name => 'testproject', :ext_management_system => @ems)

    @test_service = FactoryGirl.create(:container_service, :name => 'mysql', :container_project => @test_project)
  end

  it "creates a resource " do
    VCR.use_cassette("mixins/#{described_class.name.underscore}/create_resource",
                     :allow_unused_http_interactions => true,
                     :match_requests_on              => [:path,]) do
      test_service_two = @test_service.tidy_provider_definition
      test_service_two[:metadata][:name] = 'mysql2'
      test_service_two[:spec].delete(:clusterIP)

      result = @test_project.create_resource(test_service_two.to_h)
      expect(result).to eq(@test_project.get_resource_by_name('mysql2', 'Service'))
    end
  end

  it "updates a resource in the provider" do
    VCR.use_cassette("mixins/#{described_class.name.underscore}/update_resource",
                     :match_requests_on => [:path,]) do
      test_service_update = @test_project.get_resource_by_name('mysql', 'Service')
      test_service_update[:metadata][:annotations][:description] = "Description has been updated."
      test_service_update[:metadata][:namespace] = "shouldbecorrected"
      expect { @test_project.update_in_provider(test_service_update) }.not_to raise_exception
      result = @test_project.get_resource_by_name('mysql', 'Service')
      expect(result[:metadata][:annotations][:description]).to eq("Description has been updated.")
      expect(result[:metadata][:namespace]).to eq("testproject")
    end
  end

  it "gets correctly named resource from the provider" do
    VCR.use_cassette("mixins/#{described_class.name.underscore}/get_resoruce",
                     :match_requests_on => [:path,]) do
      result = @test_project.get_resource_by_name("mysql", "Service").to_h
      expect(result[:metadata][:name]).to eq("mysql")
      expect(result[:metadata][:namespace]).to eq("testproject")
    end
  end
end
