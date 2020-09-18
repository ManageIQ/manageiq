RSpec.describe UniqueWithinRegionValidator do
  describe "#unique_within_region" do
    context "class without STI" do
      let(:case_sensitive_class) do
        Class.new(ApplicationRecord) do
          self.table_name = "users"
          validates :name, :unique_within_region => true
        end
      end

      let(:case_insensitive_class) do
        Class.new(ApplicationRecord) do
          self.table_name = "users"
          validates :name, :unique_within_region => {:match_case => false}
        end
      end

      let(:scoped_class) do
        Class.new(ApplicationRecord) do
          self.table_name = "users"
          validates :name, :unique_within_region => {:scope => :email}
        end
      end

      let(:test_name)  { "thename" }

      let(:in_first_region_id) do
        case_sensitive_class.create!(
          :id    => case_sensitive_class.id_in_region(1, 0),
          :name  => test_name,
        ).id
      end

      let(:also_in_first_region_id) do
        case_sensitive_class.create!(
          :id    => case_sensitive_class.id_in_region(2, 0),
          :name  => test_name.upcase,
        ).id
      end

      let(:in_second_region_id) do
        case_sensitive_class.create!(
          :id    => case_sensitive_class.id_in_region(2, 1),
          :name  => test_name,
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
        also_in_first_region_rec = case_insensitive_class.new(:id => case_sensitive_class.id_in_region(2, 0), :name => test_name)
        in_second_region_rec     = case_insensitive_class.find(in_second_region_id)

        expect(in_first_region_rec.valid?).to be true
        expect(also_in_first_region_rec.valid?).to be false
        expect(in_second_region_rec.valid?).to be true
      end

      it "applies the passed scope" do
        in_first_region_rec           = scoped_class.find(in_first_region_id)
        also_in_first_region_rec      = scoped_class.find(also_in_first_region_id)
        in_second_region_rec          = scoped_class.find(in_second_region_id)

        expect(in_first_region_rec.valid?).to be true
        expect(also_in_first_region_rec.valid?).to be true
        expect(in_second_region_rec.valid?).to be true

        also_in_first_region_rec.name = test_name

        expect(also_in_first_region_rec.valid?).to be false
      end

      it "gracefully handles no name" do
        rec = case_sensitive_class.new
        expect { expect(rec.valid?).to eq(true) }.not_to make_database_queries
      end

      it "queries for a new record" do
        rec = case_sensitive_class.new(:name => 'abc')

        expect { expect(rec.valid?).to eq(true) }.to make_database_queries(:count => 1)
      end

      it "queries for a changed record" do
        rec = case_sensitive_class.create!(:name => 'abc')
        rec.name += '2'
        expect { expect(rec.valid?).to eq(true) }.to make_database_queries(:count => 1)
      end

      it "doesn't query for an unchanged record" do
        rec = case_sensitive_class.create!(:name => 'abc')
        expect { expect(rec.valid?).to eq(true) }.not_to make_database_queries
      end
    end

    context "class with STI" do
      let(:test_base_class) do
        Class.new(ApplicationRecord) do
          validates :name, :unique_within_region => true
          self.table_name = "vms"
        end
      end

      let(:test_subclass1) do
        Class.new(test_base_class) do
          def self.name
            "Subclass1"
          end
        end
      end

      let(:test_subclass2) do
        Class.new(test_base_class) do
          def self.name
            "Subclass2"
          end
        end
      end

      context "two subclasses" do
        it "raises error with non-unique names in same region" do
          test_subclass1.create!(:name => "foo")

          expect { test_subclass2.create!(:name => "foo") }
            .to raise_error(ActiveRecord::RecordInvalid, / Name is not unique within region/)
        end

        it "doesn't raise error with unique names" do
          test_subclass1.create!(:name => "foo")

          expect { test_subclass2.create!(:name => "bar") }.to_not raise_error
        end
      end
    end
  end
end
