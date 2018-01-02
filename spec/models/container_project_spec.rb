describe ContainerProject do
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
  end

  it 'adds a role to a user' do
    VCR.use_cassette("models/#{described_class.name.underscore}/add_role_to_user",
                     :match_requests_on              => [:path,],
                     :allow_unused_http_interactions => true,
                     :record                         => :new_episodes) do
      user_name = "testuser"
      found = false
      @test_project.add_role_to_user(user_name, 'admin')
      subjects = @test_project.subjects_with_role('admin')
      subjects.each do |subject|
        if subject[:name].eql?'testuser'
          found = true
        end
      end
      expect(found).to be_truthy
    end
  end

  it 'preserves existing user roles when adding a role to a user' do
    VCR.use_cassette("models/#{described_class.name.underscore}/add_role_to_user",
                     :match_requests_on              => [:path,],
                     :allow_unused_http_interactions => true,
                     :record                         => :new_episodes) do
      user_name1 = "testuser"
      user_name2 = "testuser2"
      found1 = false
      found2 = false
      @test_project.add_role_to_user(user_name1, 'admin')
      @test_project.add_role_to_user(user_name2, 'admin')
      subjects = @test_project.subjects_with_role('admin')
      subjects.each do |subject|
        if subject[:name].eql?'testuser'
          found1 = true
        elsif subject[:name].eql?'testuser2'
          found2 = true
        end
      end
      expect(found1).to be_truthy
      expect(found2).to be_truthy
    end
  end
end
