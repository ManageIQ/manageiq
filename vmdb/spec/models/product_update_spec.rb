require "spec_helper"

describe ProductUpdate do
  context "#file_from_db" do
    before(:each) do
      @binary_blob    = FactoryGirl.create(:binary_blob)
      @product_update = FactoryGirl.create(:product_update, :binary_blob => @binary_blob)
    end

    context "when deployment_target is nil" do
      before(:each) do
        @deployment_target = nil
      end

      context "when platform is windows" do
        before(:each) do
          @product_update.platform = :windows
        end

        it "returns file name ending with .exe" do
          name = @product_update.file_from_db(@deployment_target)
          name.should end_with('.exe')
        end
      end
    end

    context "import SmartProxy from disk" do
      context "parse build from rpm" do
        it "with smartrproxy rpm found" do
          ProductUpdate.stub(:get_smartproxy_version).and_return("5.2.0.26")
          ProductUpdate.stub(:rpm_version).and_return("5.2.0.26-1.el6cf")

          version, build = ProductUpdate.smartproxy_version_build("miq-host-cmd.exe", "windows")
          version.should == "5.2.0.26"
          build.should   == "1"
        end

        it "with smartrproxy rpm not found" do
          ProductUpdate.stub(:get_smartproxy_version).and_return("5.2.0.26")

          version, build = ProductUpdate.smartproxy_version_build("miq-host-cmd.exe", "windows")
          version.should be_nil
          build.should   be_nil
        end
      end
    end
  end
end
