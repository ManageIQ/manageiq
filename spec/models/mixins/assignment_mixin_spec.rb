describe AssignmentMixin do
  # too ingrained in AR - has many, acts_as_miq_taggable, ...
  let(:test_class) { MiqAlertSet }

  describe '#assignments' do
    it "finds no assignments" do
      expect(test_class.assignments).to eq({})
    end

    it "detects tags on alert_set" do
      ct1 = ctag("environment", "test")
      alert_set = FactoryGirl.create(:miq_alert_set_vm)
      alert_set.assign_to_tags([ct1], "vm")
      alert_set.reload # reload ensures the tag is set

      ct2 = ctag("environment", "staging")
      alert_set2 = FactoryGirl.create(:miq_alert_set_vm)
      alert_set2.assign_to_tags([ct2], "vm")
      alert_set2.reload # reload ensures the tag is set

      expect(test_class.assignments).to eq(
        "vm/tag/managed/environment/test"    => [alert_set],
        "vm/tag/managed/environment/staging" => [alert_set2],
      )
    end
  end

  private

  # creates a tag e.g. "/managed/environment/test"
  #
  # @param category [String] category name e.g.: "environment"
  # @param value    [String] value e.g.: "test"
  # @return [ClassificationTag] classification tag. `.tag()` is an available method
  def ctag(category = "environment", value = "test")
    env = Classification.find_by_name(category) ||
          FactoryGirl.create(:classification, :name => category, :single_value => 1)
    FactoryGirl.create(:classification_tag, :name => value, :parent => env)
  end
end
