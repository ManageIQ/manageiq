describe UniqueWithinRegionValidator do
  describe "#unique_within_region" do
    let(:case_sensitive_class) do
      Class.new(User).tap do |c|
        c.class_eval do
          validates :name, :unique_within_region => true
        end
      end
    end

    let(:case_insensitive_class) do
      Class.new(User).tap do |c|
        c.class_eval do
          validates :name, :unique_within_region => {:match_case => false}
        end
      end
    end

    let(:test_name) { "thename" }

    let(:in_first_region_id) do
      FactoryGirl.create(
        :user,
        :id   => case_sensitive_class.id_in_region(1, 0),
        :name => test_name
      ).id
    end

    let(:also_in_first_region_id) do
      FactoryGirl.create(
        :user,
        :id   => case_sensitive_class.id_in_region(2, 0),
        :name => test_name.upcase
      ).id
    end

    let(:in_second_region_id) do
      FactoryGirl.create(
        :user,
        :id   => case_sensitive_class.id_in_region(2, 1),
        :name => test_name
      ).id
    end

    it "returns true if the field is unique for the records in the region" do
      expect(case_sensitive_class.find(in_first_region_id).valid?).to be true
      expect(case_sensitive_class.find(also_in_first_region_id).valid?).to be true
      expect(case_sensitive_class.find(in_second_region_id).valid?).to be true
    end

    it "returns false if the field is not unique for the records in the region" do
      in_first_region_rec      = case_sensitive_class.find(in_first_region_id)
      also_in_first_region_rec = case_sensitive_class.find(also_in_first_region_id)
      in_second_region_rec     = case_sensitive_class.find(in_second_region_id)

      also_in_first_region_rec.name = in_first_region_rec.name

      expect(in_first_region_rec.valid?).to be true
      expect(also_in_first_region_rec.valid?).to be false
      expect(in_second_region_rec.valid?).to be true
    end

    it "is case insensitive if match_case is set to false" do
      in_first_region_rec      = case_insensitive_class.find(in_first_region_id)
      also_in_first_region_rec = case_insensitive_class.find(also_in_first_region_id)
      in_second_region_rec     = case_insensitive_class.find(in_second_region_id)

      expect(in_first_region_rec.valid?).to be false
      expect(also_in_first_region_rec.valid?).to be false
      expect(in_second_region_rec.valid?).to be true
    end
  end
end
