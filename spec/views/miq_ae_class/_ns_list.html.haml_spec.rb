describe "miq_ae_class/_ns_list.html.haml" do
  include Spec::Support::AutomationHelper

  context 'display domain properties' do
    def setup(dom)
      assign(:in_a_form, true)
      assign(:ae_ns, dom)
      assign(:edit, :new => {:ns_name => dom.name, :ns_description => "test"})
    end

    it "Check Git enabled domain", :js => true do
      dom = FactoryGirl.create(:miq_ae_git_domain)
      setup(dom)
      render
      expect(response).to have_css("input#ns_name[readonly]")
      expect(response).to have_css("input#ns_description[readonly]")
    end

    it "Check User Domain", :js => true do
      dom = FactoryGirl.create(:miq_ae_domain)
      setup(dom)
      render
      expect(response).not_to have_css("input#ns_name[readonly]")
      expect(response).not_to have_css("input#ns_description[readonly]")
    end
  end
end
