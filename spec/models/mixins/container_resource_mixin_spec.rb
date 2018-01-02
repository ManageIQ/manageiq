describe ContainerResourceMixin do
  describe 'container_project' do
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

      @dst_test_project = FactoryGirl.create(:container_project, :name => 'desttestproject', :ext_management_system => @ems)

      @test_replicator = FactoryGirl.create(:container_replicator, :name => 'mysql-1', :container_project => @test_project)

      @random_test_replicator = FactoryGirl.create(:container_replicator, :name => 'mysql', :container_project => @test_project)

      @test_service = FactoryGirl.create(:container_service, :name => 'mysql', :container_project => @test_project)

      @not_coppied_test_service = FactoryGirl.create(:container_service, :name => 'copymysql', :container_project => @test_project)

      @test_delete_service = FactoryGirl.create(:container_service, :name => 'mysql2', :container_project => @test_project)
    end

    it "returns correct namespace" do
      expect(@test_replicator.namespace).to eq("testproject")
    end

    it "knows the name of the resource" do
      expect(@test_replicator.name).to eq("mysql-1")
    end

    it 'gets annotations of the resource from the provider' do
      VCR.use_cassette("mixins/#{described_class.name.underscore}/get_resource",
                       :match_requests_on => [:path,]) do
        annotations = @test_service.annotations
        expect(annotations.kind_of?(Hash)).to be_truthy
      end
    end

    it 'gets a specific annotation of the resource from the provider' do
      VCR.use_cassette("mixins/#{described_class.name.underscore}/get_resource",
                       :match_requests_on => [:path,]) do
        annotations = @test_service.annotations("description")
        expect(annotations).to eq("Description has been updated.")
      end
    end

    it 'gets a specific annotation with non alpha numeric characters of the resource from the provider' do
      VCR.use_cassette("mixins/#{described_class.name.underscore}/get_resource2",
                       :match_requests_on => [:path,]) do
        annotations = @test_replicator.annotations("openshift.io/deployment.status-reason")
        expect(annotations).to eq("image change")
      end
    end

    it "deletes the specified resource" do
      VCR.use_cassette("mixins/#{described_class.name.underscore}/delete_resource",
                       :match_requests_on => [:path,]) do
        result = @test_delete_service.delete_from_provider
        expect(result.code).to eq(200)
      end
    end

    it "gets the spec of the resource from the provider" do
      VCR.use_cassette("mixins/#{described_class.name.underscore}/get_resource",
                       :match_requests_on => [:path,]) do
        spec = @test_service.spec
        expect(spec).to eq(:ports           => [{:name       => "mysql",
                                                 :protocol   => "TCP",
                                                 :port       => 3306,
                                                 :targetPort => 3306}],
                           :selector        => {:name => "mysql"},
                           :clusterIP       => "172.30.208.196",
                           :type            => "ClusterIP",
                           :sessionAffinity => "None")
      end
    end

    it "gets a tidy definition of the resource from the provider" do
      VCR.use_cassette("mixins/#{described_class.name.underscore}/get_resource",
                       :match_requests_on => [:path,]) do
        resource = @test_service.tidy_provider_definition
        expect(resource[:metadata][:selfLink]).to be_nil
        expect(resource[:metadata][:uid]).to be_nil
        expect(resource[:metadata][:resourceVersion]).to be_nil
        expect(resource[:metadata][:creationTimestamp]).to be_nil
      end
    end

    it "patches the spec of the resource" do
      VCR.use_cassette("mixins/#{described_class.name.underscore}/update_resource",
                       :match_requests_on => [:path,]) do

        spec = {:ports           => [{:name       => "mysql",
                                      :protocol   => "TCP",
                                      :port       => 3306,
                                      :targetPort => 3306},
                                     {:name       => "http",
                                      :protocol   => "TCP",
                                      :port       => 80,
                                      :targetPort => 80}],
                :selector        => {:name => "mysql"},
                :type            => "ClusterIP",
                :clusterIP       => "172.30.208.196",
                :sessionAffinity => "None"}
        @test_service.spec = spec
        newspec = @test_service.spec
        expect(newspec).to eq(spec)
      end
    end
  end
end
