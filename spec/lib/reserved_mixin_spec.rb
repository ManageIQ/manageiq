describe ReservedMixin do
  let(:test_class) do
    Class.new(ActiveRecord::Base) do
      def self.name; "TestClass"; end
      self.table_name = "vms"
      include ReservedMixin
      reserve_attribute :some_field, :string
    end
  end

  context ".reserve_attribute" do
    it "normal case" do
      t = test_class.new
      expect(t).to respond_to(:some_field)
      expect(t).to respond_to(:some_field?)
      expect(t).to respond_to(:some_field=)

      t.some_field = "test"
      expect(t.some_field).to eq("test")
      expect(t.some_field?).to be_truthy

      t.some_field = nil
      expect(t.some_field).to  be_nil
      expect(t.some_field?).to be_falsey
    end

    it "with multiple fields" do
      reserved_attributes = Module.new do
        def self.included(klass)
          klass.reserve_attribute :another_field, :string
          klass.reserve_attribute :a_third_field, :string
        end
      end
      test_class.include(reserved_attributes)

      t = test_class.new
      expect(t).to respond_to(:another_field)
      expect(t).to respond_to(:another_field?)
      expect(t).to respond_to(:another_field=)
      expect(t).to respond_to(:a_third_field)
      expect(t).to respond_to(:a_third_field?)
      expect(t).to respond_to(:a_third_field=)
    end
  end

  context "#reserved" do
    before(:each) do
      @t = test_class.create
    end

    it "without existing reserved data" do
      expect(@t.reserved).to be_nil
    end

    it "with existing reserved data" do
      FactoryGirl.create(:reserve, :resource => @t, :reserved => {:some_field => "test"})
      @t.reload

      expect(@t.reserved).to eq({:some_field => "test"})
    end
  end

  context "#reserved=" do
    before(:each) do
      @t = test_class.create
    end

    context "to a non-empty Hash" do
      it "without existing reserved data" do
        @t.reserved = {:some_field => "test"}
        @t.save!

        expect(Reserve.count).to eq(1)
        expect(Reserve.first).to have_attributes(
          :resource_type => @t.class.name,
          :resource_id   => @t.id,
          :reserved      => {:some_field => "test"}
        )
      end

      it "with existing reserved data" do
        FactoryGirl.create(:reserve, :resource => @t, :reserved => {:some_field => "test"})
        @t.reload

        @t.reserved = {:some_field => "test2"}
        @t.save!

        expect(Reserve.count).to eq(1)
        expect(Reserve.first).to have_attributes(
          :resource_type => @t.class.name,
          :resource_id   => @t.id,
          :reserved      => {:some_field => "test2"}
        )
      end
    end

    context "to an empty Hash" do
      it "without existing reserved data" do
        @t.reserved = {}
        @t.save!

        expect(Reserve.count).to eq(0)
      end

      it "with existing reserved data" do
        FactoryGirl.create(:reserve, :resource => @t, :reserved => {:some_field => "test"})
        @t.reload

        @t.reserved = {}
        @t.save!

        expect(Reserve.count).to eq(0)
      end
    end

    context "to nil" do
      it "without existing reserved data" do
        @t.reserved = nil
        @t.save!

        expect(Reserve.count).to eq(0)
      end

      it "with existing reserved data" do
        FactoryGirl.create(:reserve, :resource => @t, :reserved => {:some_field => "test"})
        @t.reload

        @t.reserved = nil
        @t.save!

        expect(Reserve.count).to eq(0)
      end
    end
  end

  context "#reserved_hash_get" do
    before(:each) do
      @t = test_class.create
    end

    it "without existing reserved data" do
      expect(@t.reserved_hash_get(:some_field)).to    be_nil
      expect(@t.reserved_hash_get(:another_field)).to be_nil
    end

    it "with existing reserved data" do
      FactoryGirl.create(:reserve, :resource => @t, :reserved => {:some_field => "test"})
      @t.reload

      expect(@t.reserved_hash_get(:some_field)).to eq("test")
      expect(@t.reserved_hash_get(:another_field)).to be_nil
    end
  end

  context "#reserved_hash_set" do
    before(:each) do
      @t = test_class.create
    end

    context "to a non-nil value" do
      it "without existing reserved data" do
        @t.reserved_hash_set(:some_field, "test")
        @t.save!

        expect(Reserve.count).to eq(1)
        expect(Reserve.first).to have_attributes(
          :resource_type => @t.class.name,
          :resource_id   => @t.id,
          :reserved      => {:some_field => "test"}
        )
      end

      context "with existing reserved data" do
        before(:each) do
          FactoryGirl.create(:reserve, :resource => @t, :reserved => {:some_field => "test"})
          @t.reload
        end

        it "updating an existing value" do
          @t.reserved_hash_set(:some_field, "test2")
          @t.save!

          expect(Reserve.count).to eq(1)
          expect(Reserve.first).to have_attributes(
            :resource_type => @t.class.name,
            :resource_id   => @t.id,
            :reserved      => {:some_field => "test2"}
          )
        end

        it "adding a new value" do
          @t.reserved_hash_set(:another_field, "test2")
          @t.save!

          expect(Reserve.count).to eq(1)
          expect(Reserve.first).to have_attributes(
            :resource_type => @t.class.name,
            :resource_id   => @t.id,
            :reserved      => {:some_field => "test", :another_field => "test2"}
          )
        end
      end
    end

    context "to nil" do
      it "without existing reserved data" do
        @t.reserved_hash_set(:some_field, nil)
        @t.save!

        expect(Reserve.count).to eq(0)
      end

      context "with existing reserved data" do
        it "of only this attribute" do
          FactoryGirl.create(:reserve, :resource => @t, :reserved => {:some_field => "test"})
          @t.reload

          @t.reserved_hash_set(:some_field, nil)
          @t.save!

          expect(Reserve.count).to eq(0)
        end

        it "of multiple attributes" do
          FactoryGirl.create(:reserve, :resource => @t, :reserved => {:some_field => "test", :another_field => "test2"})
          @t.reload

          @t.reserved_hash_set(:some_field, nil)
          @t.save!

          expect(Reserve.count).to eq(1)
          expect(Reserve.first).to have_attributes(
            :resource_type => @t.class.name,
            :resource_id   => @t.id,
            :reserved      => {:another_field => "test2"}
          )
        end
      end
    end
  end

  context "#reserved_hash_migrate" do
    before(:each) do
      @t = test_class.create
    end

    context "when the reserved key name matches the column name" do
      it "with a single key" do
        FactoryGirl.create(:reserve, :resource => @t, :reserved => {:name => "test"})
        @t.reload

        @t.reserved_hash_migrate(:name)

        expect(Reserve.count).to eq(0)
        expect(@t.name).to eq("test")
      end

      it "with multiple keys" do
        FactoryGirl.create(:reserve, :resource => @t, :reserved => {:name => "test", :description => "test2"})
        @t.reload

        @t.reserved_hash_migrate(:name, :description)

        expect(Reserve.count).to eq(0)
        expect(@t.name).to eq("test")
        expect(@t.description).to eq("test2")
      end
    end

    context "when the reserved key name does not match the column name" do
      it "with a single key" do
        FactoryGirl.create(:reserve, :resource => @t, :reserved => {:some_field => "test"})
        @t.reload

        @t.reserved_hash_migrate(:some_field => :name)

        expect(Reserve.count).to eq(0)
        expect(@t.name).to eq("test")
      end

      it "with multiple keys" do
        FactoryGirl.create(:reserve, :resource => @t, :reserved => {:some_field => "test", :another_field => "test2"})
        @t.reload

        @t.reserved_hash_migrate(:some_field => :name, :another_field => :description)

        expect(Reserve.count).to eq(0)
        expect(@t.name).to eq("test")
        expect(@t.description).to eq("test2")
      end
    end
  end

  context "#save" do
    context "will touch the parent record's updated_on" do
      before(:each) do
        @t = test_class.create
        @last_update = @t.updated_on
      end

      it "without existing reserved data" do
        @t.update_attribute(:some_field, "test")
        expect(@t.updated_on).not_to eq(@last_update)
      end

      context "with existing reserved data" do
        before(:each) do
          FactoryGirl.create(:reserve, :resource => @t, :reserved => {:some_field => "test"})
          @t.reload
        end

        it "and data changing" do
          @t.update_attribute(:some_field, "test2")
          expect(@t.updated_on).not_to eq(@last_update)
        end
      end
    end
  end
end
