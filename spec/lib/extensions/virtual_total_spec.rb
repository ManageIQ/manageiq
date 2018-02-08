describe VirtualTotal do
  before(:each) do
    # rubocop:disable Style/SingleLineMethods, Layout/EmptyLineBetweenDefs, Naming/AccessorMethodName
    class VitualTotalTestBase < ActiveRecord::Base
      self.abstract_class = true

      establish_connection :adapter => 'sqlite3', :database => ':memory:'

      include VirtualFields

      # HACK:  not sure the right way to do this
      def self.id_increment
        @id_increment ||= 0
        @id_increment  += 1
      end
    end

    ActiveRecord::Schema.define do
      def self.connection; VitualTotalTestBase.connection; end
      def self.set_pk_sequence!(*); end
      self.verbose = false

      create_table :vt_authors do |t|
        t.string   :name
      end

      create_table :vt_books do |t|
        t.integer  :author_id
        t.string   :name
        t.boolean  :published, :default => false
        t.boolean  :special,   :default => false
        t.integer  :rating
        t.datetime :created_on
      end
    end

    class VtAuthor < VitualTotalTestBase
      def self.connection; VitualTotalTestBase.connection; end

      has_many :books,                             :class_name => "VtBook", :foreign_key => "author_id"
      has_many :published_books, -> { published }, :class_name => "VtBook", :foreign_key => "author_id"
      has_many :wip_books,       -> { wip },       :class_name => "VtBook", :foreign_key => "author_id"

      virtual_total :total_books, :books
      virtual_total :total_books_published, :published_books
      virtual_total :total_books_in_progress, :wip_books

      def self.create_with_books(count = 0)
        create!(:name => "foo", :id => id_increment).tap { |author| author.create_books(count) }
      end

      def create_books(count, create_attrs = {})
        count.times do
          attrs = {
            :name   => "bar",
            :author => self,
            :id     => VtBook.id_increment
          }.merge(create_attrs)
          VtBook.create(attrs)
        end
      end
    end

    class VtBook < VitualTotalTestBase
      def self.connection; VitualTotalTestBase.connection end

      belongs_to :author, :class_name => "VtAuthor"
      scope :published, -> { where(:published => true)  }
      scope :wip,       -> { where(:published => false) }
    end
    # rubocop:enable Style/SingleLineMethods, Layout/EmptyLineBetweenDefs, Naming/AccessorMethodName
  end

  after(:each) do
    VitualTotalTestBase.remove_connection
    Object.send(:remove_const, :VtAuthor)
    Object.send(:remove_const, :VtBook)
    Object.send(:remove_const, :VitualTotalTestBase)
  end

  describe ".virtual_total" do
    context "with a standard has_many" do
      it "sorts by total" do
        author2 = VtAuthor.create_with_books(2)
        author0 = VtAuthor.create_with_books(0)
        author1 = VtAuthor.create_with_books(1)

        expect(VtAuthor.order(:total_books).pluck(:id))
          .to eq([author0, author1, author2].map(&:id))
      end

      it "calculates totals locally" do
        author0_id = VtAuthor.create_with_books(0).id
        author2_id = VtAuthor.create_with_books(2).id
        expect do
          expect(VtAuthor.find(author0_id).total_books).to eq(0)
          expect(VtAuthor.find(author2_id).total_books).to eq(2)
        end.to match_query_limit_of(4)
      end

      it "can bring back totals in primary query" do
        author3 = VtAuthor.create_with_books(3)
        author1 = VtAuthor.create_with_books(1)
        author2 = VtAuthor.create_with_books(2)
        expect do
          author_query = VtAuthor.select(:id, :total_books)
          expect(author_query).to match_array([author3, author1, author2])
          expect(author_query.map(&:total_books)).to match_array([3, 1, 2])
        end.to match_query_limit_of(1)
      end
    end

    context "with a has_many that includes a scope" do
      it "sorts by total" do
        author2 = VtAuthor.create_with_books(2)
        author2.create_books(1, :published => true)
        author0 = VtAuthor.create_with_books(0)
        author0.create_books(2, :published => true)
        author1 = VtAuthor.create_with_books(1)

        expect(VtAuthor.order(:total_books_published).pluck(:id))
          .to eq([author1, author2, author0].map(&:id))
        expect(VtAuthor.order(:total_books_in_progress).pluck(:id))
          .to eq([author0, author1, author2].map(&:id))
      end

      it "calculates totals locally" do
        author0 = VtAuthor.create_with_books(0)
        author0.create_books(2, :published => true)
        author2 = VtAuthor.create_with_books(2)
        author2.create_books(1, :published => true)

        expect do
          expect(VtAuthor.find(author0.id).total_books).to eq(2)
          expect(VtAuthor.find(author0.id).total_books_published).to eq(2)
          expect(VtAuthor.find(author0.id).total_books_in_progress).to eq(0)
          expect(VtAuthor.find(author2.id).total_books).to eq(3)
          expect(VtAuthor.find(author2.id).total_books_published).to eq(1)
          expect(VtAuthor.find(author2.id).total_books_in_progress).to eq(2)
        end.to match_query_limit_of(12)
      end

      it "can bring back totals in primary query" do
        author3 = VtAuthor.create_with_books(3)
        author3.create_books(4, :published => true)
        author1 = VtAuthor.create_with_books(1)
        author1.create_books(5, :published => true)
        author2 = VtAuthor.create_with_books(2)
        author2.create_books(6, :published => true)

        expect do
          cols = %i(id total_books total_books_published total_books_in_progress)
          author_query = VtAuthor.select(*cols).to_a
          expect(author_query).to match_array([author3, author1, author2])
          expect(author_query.map(&:total_books)).to match_array([7, 6, 8])
          expect(author_query.map(&:total_books_published)).to match_array([4, 5, 6])
          expect(author_query.map(&:total_books_in_progress)).to match_array([3, 1, 2])
        end.to match_query_limit_of(1)
      end
    end

    context "with order clauses in the relation" do
      before(:each) do
        # Monkey patching VtAuthor for these specs
        class VtAuthor < VitualTotalTestBase
          has_many :recently_published_books, -> { published.order(:created_on => :desc) },
                   :class_name => "VtBook", :foreign_key => "author_id"

          virtual_total :total_recently_published_books, :recently_published_books
          virtual_aggregate :sum_recently_published_books_rating, :recently_published_books, :sum, :rating
        end
      end

      it "sorts by total" do
        author2 = VtAuthor.create_with_books(2)
        author2.create_books(1, :published => true, :rating => 5)
        author0 = VtAuthor.create_with_books(0)
        author0.create_books(2, :published => true, :rating => 2)
        author1 = VtAuthor.create_with_books(1)

        expect(VtAuthor.order(:total_recently_published_books).pluck(:id))
          .to eq([author1, author2, author0].map(&:id))
        expect(VtAuthor.order(:sum_recently_published_books_rating).pluck(:id))
          .to eq([author1, author0, author2].map(&:id))
      end

      it "calculates totals locally" do
        author0 = VtAuthor.create_with_books(0)
        author0.create_books(2, :published => true, :rating => 2)
        author2 = VtAuthor.create_with_books(2)
        author2.create_books(1, :published => true, :rating => 5)

        expect do
          expect(VtAuthor.find(author0.id).total_recently_published_books).to eq(2)
          expect(VtAuthor.find(author0.id).sum_recently_published_books_rating).to eq(4)
          expect(VtAuthor.find(author2.id).total_recently_published_books).to eq(1)
          expect(VtAuthor.find(author2.id).sum_recently_published_books_rating).to eq(5)
        end.to match_query_limit_of(8)
      end

      it "can bring back totals in primary query" do
        author3 = VtAuthor.create_with_books(3)
        author3.create_books(2, :published => true, :rating => 2)
        author1 = VtAuthor.create_with_books(1)
        author1.create_books(3, :published => true, :rating => 1)
        author2 = VtAuthor.create_with_books(2)
        author2.create_books(1, :published => true, :rating => 5)

        expect do
          cols = %i(id total_recently_published_books sum_recently_published_books_rating)
          author_query = VtAuthor.select(*cols).to_a
          expect(author_query).to match_array([author3, author1, author2])
          expect(author_query.map(&:total_recently_published_books)).to match_array([2, 3, 1])
          expect(author_query.map(&:sum_recently_published_books_rating)).to match_array([4, 3, 5])
        end.to match_query_limit_of(1)
      end
    end

    context "with a special books class" do
      before(:each) do
        class SpecialVtBook < VtBook
          default_scope { where(:special => true) }

          self.table_name = 'vt_books'
        end

        # Monkey patching VtAuthor for these specs
        class VtAuthor < VitualTotalTestBase
          has_many :special_books,
                   :class_name => "SpecialVtBook", :foreign_key => "author_id"
          has_many :published_special_books, -> { published },
                   :class_name => "SpecialVtBook", :foreign_key => "author_id"

          virtual_total :total_special_books, :special_books
          virtual_total :total_special_books_published, :published_special_books
        end
      end

      after(:each) do
        Object.send(:remove_const, :SpecialVtBook)
      end

      context "with a has_many that includes a scope" do
        it "sorts by total" do
          author2 = VtAuthor.create_with_books(2)
          author2.create_books(5, :special => true)
          author2.create_books(1, :special => true, :published => true)
          author0 = VtAuthor.create_with_books(0)
          author0.create_books(2, :special => true)
          author0.create_books(2, :special => true, :published => true)
          author1 = VtAuthor.create_with_books(1)

          expect(VtAuthor.order(:total_special_books).pluck(:id))
            .to eq([author1, author0, author2].map(&:id))
          expect(VtAuthor.order(:total_special_books_published).pluck(:id))
            .to eq([author1, author2, author0].map(&:id))
        end

        it "calculates totals locally" do
          author0 = VtAuthor.create_with_books(0)
          author0.create_books(2, :special => true)
          author0.create_books(2, :special => true, :published => true)
          author2 = VtAuthor.create_with_books(2)
          author2.create_books(5, :special => true)
          author2.create_books(1, :special => true, :published => true)

          expect do
            expect(VtAuthor.find(author0.id).total_books).to eq(4)
            expect(VtAuthor.find(author0.id).total_special_books).to eq(4)
            expect(VtAuthor.find(author0.id).total_special_books_published).to eq(2)
            expect(VtAuthor.find(author2.id).total_books).to eq(8)
            expect(VtAuthor.find(author2.id).total_special_books).to eq(6)
            expect(VtAuthor.find(author2.id).total_special_books_published).to eq(1)
          end.to match_query_limit_of(12)
        end

        it "can bring back totals in primary query" do
          author3 = VtAuthor.create_with_books(3)
          author3.create_books(4, :published => true)
          author1 = VtAuthor.create_with_books(1)
          author1.create_books(2, :special => true)
          author1.create_books(2, :special => true, :published => true)
          author2 = VtAuthor.create_with_books(2)
          author2.create_books(5, :special => true)
          author2.create_books(1, :special => true, :published => true)

          expect do
            cols = %i(
              id
              total_books
              total_books_published
              total_special_books
              total_special_books_published
            )
            author_query = VtAuthor.select(*cols).to_a
            expect(author_query).to match_array([author3, author1, author2])
            expect(author_query.map(&:total_books)).to match_array([7, 5, 8])
            expect(author_query.map(&:total_books_published)).to match_array([4, 2, 1])
            expect(author_query.map(&:total_special_books)).to match_array([0, 4, 6])
            expect(author_query.map(&:total_special_books_published)).to match_array([0, 2, 1])
          end.to match_query_limit_of(1)
        end
      end
    end
  end

  describe ".virtual_total (with real has_many relation ems#total_vms)" do
    let(:base_model) { ExtManagementSystem }
    it "sorts by total" do
      ems0 = model_with_children(0)
      ems2 = model_with_children(2)
      ems1 = model_with_children(1)

      expect(base_model.order(:total_vms).pluck(:id))
        .to eq([ems0, ems1, ems2].map(&:id))
    end

    it "calculates totals locally" do
      expect(model_with_children(0).total_vms).to eq(0)
      expect(model_with_children(2).total_vms).to eq(2)
    end

    it "can bring back totals in primary query" do
      m3 = model_with_children(3)
      m1 = model_with_children(1)
      m2 = model_with_children(2)
      mc = m1.class
      expect {
        ms = mc.select(:id, mc.arel_attribute(:total_vms).as("total_vms"))
        expect(ms).to match_array([m3, m2, m1])
        expect(ms.map(&:total_vms)).to match_array([3, 2, 1])
      }.to match_query_limit_of(1)
    end

    def model_with_children(count)
      FactoryGirl.create(:ext_management_system).tap do |ems|
        FactoryGirl.create_list(:vm, count, :ext_management_system => ems) if count > 0
      end
    end
  end

  describe ".virtual_total (with virtual relation (resource_pool#total_vms)" do
    let(:base_model) { ResourcePool }
    # it can not sort by virtual

    it "calculates totals locally" do
      expect(model_with_children(0).total_vms).to eq(0)
      expect(model_with_children(2).total_vms).to eq(2)
    end

    it "is not defined in sql" do
      expect(base_model.attribute_supported_by_sql?(:total_vms)).to be(false)
    end

    def model_with_children(count)
      FactoryGirl.create(:resource_pool).tap do |pool|
        count.times do |_i|
          vm = FactoryGirl.create(:vm)
          vm.with_relationship_type("ems_metadata") { vm.set_parent pool }
        end
      end
    end
  end

  describe ".virtual_total (with through relation (host#v_total_storages)" do
    let(:base_model) { Host }

    it "calculates totals locally" do
      expect(model_with_children(0).v_total_storages).to eq(0)
      expect(model_with_children(2).v_total_storages).to eq(2)
    end

    it "is not defined in sql" do
      expect(base_model.attribute_supported_by_sql?(:v_total_storages)).to be(false)
    end

    def model_with_children(count)
      FactoryGirl.create(:host).tap do |host|
        count.times { host.storages.create(FactoryGirl.attributes_for(:storage)) }
      end.reload
    end
  end

  # Duplicated from VmOrTemplateSpec#provisioned_storage since this can't be
  # simulated in SQLite, since they allow you to have an ORDER BY with a column
  # that isn't in the SELECT clause...
  #
  # Keep this test here to confirm the virtual_aggregate works when an order
  # exists on the scope, unless this is aggregate is deleted (then feel free to
  # remove).
  describe ".virtual_total (with real has_many relation and .order() in scope vm#provisioned_storage)" do
    context "with no hardware" do
      let(:base_model) { Vm }

      it "calculates totals locally" do
        expect(model_with_children(0).provisioned_storage).to eq(0.0)
        expect(model_with_children(2).provisioned_storage).to eq(20.0)
      end

      it "uses calculated (inline) attribute" do
        vm1   = model_with_children(0)
        vm2   = model_with_children(2)
        query = ManageIQ::Providers::Vmware::InfraManager::Vm.select(:id, :provisioned_storage).to_a
        expect do
          expect(query).to match_array([vm1, vm2])
          expect(query.map(&:provisioned_storage)).to match_array([0.0, 20.0])
        end.to match_query_limit_of(0)
      end

      def model_with_children(count)
        FactoryGirl.create(:vm_vmware, :hardware => FactoryGirl.create(:hardware)).tap do |vm|
          count.times { vm.hardware.disks.create(:size => 10.0) }
        end.reload
      end
    end
  end
end
