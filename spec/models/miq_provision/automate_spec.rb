require "spec_helper"

describe MiqProvision do
  context "#get_domain_details" do
    let(:password) { "secret sauce" }
    let(:domain) { "domain1" }
    let(:enc_password) { MiqAePassword.encrypt(password) }
    let(:t1) { u1.current_tenant }
    let(:u1) { FactoryGirl.create(:user_with_group) }
    let(:options) { {'domains' => [{:name => domain, :bind_password => enc_password}]} }
    let(:workspace) { instance_double("MiqAeEngine::MiqAeWorkspace", :root => options) }
    let(:prov) { FactoryGirl.build(:miq_provision, :tenant => t1) }

    def stub_method
      MiqAeEngine.should_receive(:resolve_automation_object).with do |uri, _, _, _|
        uri.should eq('REQUEST')
      end.and_return(workspace)
    end

    context "with password" do
      it "class method" do
        stub_method
        details = MiqProvision.get_domain_details(domain, true, u1)
        expect(details[:name]).to eq(domain)
        expect(MiqAePassword.decrypt(details[:bind_password])).to eq(password)
      end
    end

    context "without password" do
      it "class method" do
        stub_method
        details = MiqProvision.get_domain_details(domain, false, u1)
        expect(details[:name]).to eq(domain)
        expect(details[:bind_password]).to be_nil
      end
    end
  end
end
