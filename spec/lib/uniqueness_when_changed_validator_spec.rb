RSpec.describe UniquenessWhenChangedValidator do
  # MiqAlert currently only has one validation for uniqueness
  describe "#uniqueness_when_changed" do
    it "queries for a new record" do
      alert = FactoryBot.build(:miq_alert)
      expect { alert.valid? }.to make_database_queries(:count => 1)
    end

    it "queries for a changed record" do
      alert = FactoryBot.create(:miq_alert)
      alert.description = alert.description + "_2"
      expect { alert.valid? }.to make_database_queries(:count => 1)
    end

    it "doesn't query for an unchanged record" do
      alert = FactoryBot.create(:miq_alert)
      expect { alert.valid? }.not_to make_database_queries
    end

    it "actually does a uniqueness check" do
      alert = FactoryBot.create(:miq_alert)
      alert2 = FactoryBot.build(:miq_alert, :description => alert.description)
      expect(alert2).not_to be_valid
    end
  end
end
