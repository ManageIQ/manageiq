require "spec_helper"
include UiConstants

describe OpsController do
  render_views

  context "::RbacTree" do
    before do
      [MiqRegion, MiqProductFeature].each(&:seed)
      feature = MiqProductFeature.find_all_by_identifier("everything")
      @role   = FactoryGirl.create(:miq_user_role, :name => "Role", :miq_product_features => feature)
    end

    context "#build" do
      it "builds features tree" do
        controller.instance_variable_set(:@role, @role)
        controller.instance_variable_set(:@role_features, @role.feature_identifiers.sort)
        features_tree = controller.send(:rbac_build_features_tree)
        features_tree.should include("Access Rules for all Virtual Machines")
        expect(response.status).to eq(200)
      end
    end
  end
end
