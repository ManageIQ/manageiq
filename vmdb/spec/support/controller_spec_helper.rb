module ControllerSpecHelper
  def assigns(key = nil)
    if key.nil?
      @controller.view_assigns.symbolize_keys
    else
      @controller.view_assigns[key.to_s]
    end
  end

  def set_user_privileges
    described_class.any_instance.stub(:set_user_time_zone)
    controller.stub(:check_privileges).and_return(true)
    user = FactoryGirl.create(:user)
    User.stub(:current_user => user)
    User.any_instance.stub(:role_allows?).and_return(true)
  end

  def seed_specific_product_features(feature)
    MiqProductFeature.seed_specific_features(feature)
    create_user_with_product_features(MiqProductFeature.find_all_by_identifier([feature]))
  end

  def seed_specific_product_features_with_user_settings(feature, settings)
    seed_specific_product_features(feature)
    @test_user.settings = settings
    controller.instance_variable_set(:@settings,  @test_user.settings)
  end

  def seed_all_product_features(settings)
    create_user_with_product_features(MiqProductFeature.find_all_by_identifier(["everything"]))
    @test_user.settings = settings
    controller.instance_variable_set(:@settings,  @test_user.settings)
    controller.stub(:role_allows).and_return(true)
  end

  def create_user_with_product_features(product_feature)
    test_role  = FactoryGirl.create(:miq_user_role,
                                    :name                 => "test_role",
                                    :miq_product_features => product_feature)
    test_group = FactoryGirl.create(:miq_group, :miq_user_role => test_role)
    @test_user       = FactoryGirl.create(:user,
                                          :name       => 'test_user',
                                          :miq_groups => [test_group])
    User.stub(:current_user => @test_user)
  end

  shared_context "valid session" do
    let(:privilege_checker_service) { instance_double("PrivilegeCheckerService", :valid_session?  => true) }
    let(:request_referer_service)   { instance_double("RequestRefererService",   :allowed_access? => true) }

    before do
      controller.stub(:set_user_time_zone)
      PrivilegeCheckerService.stub(:new).and_return(privilege_checker_service)
      RequestRefererService.stub(:new).and_return(request_referer_service)
    end
  end
end
