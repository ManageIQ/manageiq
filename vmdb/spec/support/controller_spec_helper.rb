module ControllerSpecHelper
  def assigns(key = nil)
    if key.nil?
      @controller.view_assigns.symbolize_keys
    else
      @controller.view_assigns[key.to_s]
    end
  end

  def set_user_privileges(user = FactoryGirl.create(:user))
    allow(User).to receive(:server_timezone).and_return("UTC")
    described_class.any_instance.stub(:set_user_time_zone)

    # TODO: remove these stubs
    controller.stub(:check_privileges).and_return(true)
    login_as user
    User.any_instance.stub(:role_allows?).and_return(true)
  end

  def seed_specific_product_features(*features)
    features.flatten!
    EvmSpecHelper.seed_specific_product_features(features)
    create_user_with_product_features(MiqProductFeature.find_all_by_identifier(features))
  end

  def seed_specific_product_features_with_user_settings(features, settings)
    seed_specific_product_features(features)
    @test_user.settings = settings
    controller.instance_variable_set(:@settings, @test_user.settings)
  end

  def seed_all_product_features(settings)
    seed_specific_product_features_with_user_settings(%w(everything), settings)
    controller.stub(:role_allows).and_return(true)
  end

  def create_user_with_product_features(product_features)
    test_role  = FactoryGirl.create(:miq_user_role,
                                    :name                 => "test_role",
                                    :miq_product_features => product_features)
    test_group = FactoryGirl.create(:miq_group,
                                    :miq_user_role => test_role)
    @test_user = FactoryGirl.create(:user,
                                    :name       => 'test_user',
                                    :miq_groups => [test_group])
    login_as @test_user
  end

  shared_context "valid session" do
    let(:privilege_checker_service) { auto_loaded_instance_double("PrivilegeCheckerService", :valid_session?  => true) }
    let(:request_referer_service)   { auto_loaded_instance_double("RequestRefererService",   :allowed_access? => true) }

    before do
      controller.stub(:set_user_time_zone)
      PrivilegeCheckerService.stub(:new).and_return(privilege_checker_service)
      RequestRefererService.stub(:new).and_return(request_referer_service)
    end
  end
end
