describe ApplicationHelper::Toolbar::MiqAeDomainCenter do
  describe "definition of class" do
    it "contains the miq_ae_git_refresh button" do
      miq_ae_domain_center = Kernel.const_get("ApplicationHelper::Toolbar::MiqAeDomainCenter")
      buttons = miq_ae_domain_center.definition["miq_ae_domain_vmdb"].buttons
      button_names = []
      buttons.each do |button|
        button_names += button[:items].pluck(:id)
      end
      expect(button_names).to include("miq_ae_git_refresh")
    end
  end
end
