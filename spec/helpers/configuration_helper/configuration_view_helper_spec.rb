describe ConfigurationHelper::ConfigurationViewHelper do
  context "#active_icon" do
    let(:active_icon) { helper.send(:active_icon, 'image', 'text') }

    it "renders all //li/i hierarchy" do
      expect(active_icon).to have_xpath('//li/i')
    end

    it "renders active li" do
      expect(active_icon).to have_xpath('//li[@class="active"]')
    end

    it "renders i with correct class" do
      expect(active_icon).to have_xpath('//i[@class="image"]')
    end

    it "renders i with correct title" do
      expect(active_icon).to have_xpath('//i[@title="text"]')
    end
  end
end
