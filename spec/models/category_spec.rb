RSpec.describe Category do
  describe "#tags" do
    it "works" do
      clergy        = FactoryBot.create(:classification,     :name => "clergy", :single_value => 1)
      clergy_bishop = FactoryBot.create(:classification_tag, :name => "bishop", :parent => clergy)
      chess         = FactoryBot.create(:classification,     :name => "chess",  :single_value => 1)
      chess_bishop  = FactoryBot.create(:classification_tag, :name => "bishop", :parent => chess)

      cat_cl  = Category.find_by(:id => clergy.id)
      tag_clb = clergy_bishop.tag
      cat_ch  = Category.find_by(:id => chess.id)
      tag_chb = chess_bishop.tag

      expect(cat_cl.tags).to eq([tag_clb])
      expect(cat_ch.tags).to eq([tag_chb])
    end
  end
end
