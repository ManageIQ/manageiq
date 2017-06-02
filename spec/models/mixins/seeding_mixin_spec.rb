describe SeedingMixin do
  class CreateAllOfTheThings < ActiveRecord::Migration
    def self.up
      create_table :some_things do |t|
        t.column   :name, :string
        t.column   :description, :string
        t.column   :guid, :string, :limit => 36
      end

      create_table :some_other_things do |t|
        t.column     :name, :string
        t.column     :description, :string
        t.column     :guid, :string, :limit => 36
        t.belongs_to :some_thing, :type => :bigint
      end
    end

    def self.down
      drop_table :some_things
      drop_table :some_other_things
    end
  end

  class SomeThing < ApplicationRecord
    include SeedingMixin
  end

  class SomeOtherThing < ApplicationRecord
    include SeedingMixin
  end

  FIRST_THING = {
    :name        => 'thinga',
    :description => 'very important!',
    :guid        => 'b330acc8-5898-434f-9e9e-4099453fbb52'
  }.freeze

  SECOND_THING = {
    :name        => 'mabob',
    :description => 'less important!',
    :guid        => '90a8ef74-0e20-44b1-aefd-8075a5a616be'
  }.freeze

  before(:each) do
    stub_const("ApplicationRecord::FIXTURE_DIR", Rails.root.join("spec/fixtures/files"))
  end

  before(:all) do
    silence_stdout do
      CreateAllOfTheThings.up
    end
  end

  after(:all) do
    silence_stdout do
      CreateAllOfTheThings.down
    end
  end

  def silence_stdout
    original = STDOUT
    $stdout = File.new(File.join('/', 'dev', 'null'), 'w')
    yield
  ensure
    $stdout = original
  end

  it "ignores a class with no fixture file" do
    SomeThing.seed_model
    expect(SomeThing.count).to be(0)
  end

  it "seeds two records" do
    expect(SomeThing).to receive(:load_fixtures).once.with('some_things').and_return([FIRST_THING, SECOND_THING])
    SomeThing.seed_model

    expect(SomeThing.count).to be(2)
    expect(SomeThing.first).to have_attributes(FIRST_THING)
    expect(SomeThing.second).to have_attributes(SECOND_THING)
  end

  it "updates a record" do
    expect(SomeThing).to receive(:load_fixtures).once.with('some_things').and_return([FIRST_THING])
    SomeThing.seed_model
    expect(SomeThing.first.name).to eq(FIRST_THING[:name])
    expect(SomeThing).to receive(:load_fixtures).once.with('some_things')
      .and_return([FIRST_THING.merge(:name => 'NO!')])
    SomeThing.seed_model
    expect(SomeThing.first.name).to eq('NO!')
  end

  # has many

  context "has many" do
    before do
      SomeThing.class_eval do
        has_many :some_other_things
      end
    end

    it "seeds something with :some_other_things missing" do
      expect(SomeThing).to receive(:load_fixtures).once.with('some_things').and_return([FIRST_THING])

      SomeThing.seed_model(SomeThing.with_many(:some_other_things, :name))

      expect(SomeThing.first.some_other_things).to eq([])
    end

    it "seeds something with :some_other_things = nil" do
      expect(SomeThing).to receive(:load_fixtures).once.with('some_things').and_return(
        [
          FIRST_THING.merge(
            :some_other_things => nil
          )
        ]
      )
      SomeThing.seed_model(SomeThing.with_many(:some_other_things, :name))

      expect(SomeThing.first.some_other_things).to eq([])
    end

    it "seeds something with :some_other_things = []" do
      expect(SomeThing).to receive(:load_fixtures).once.with('some_things').and_return(
        [
          FIRST_THING.merge(
            :some_other_things => []
          )
        ]
      )
      SomeThing.seed_model(SomeThing.with_many(:some_other_things, :name))

      expect(SomeThing.first.some_other_things).to eq([])
    end

    it "seeds something with :some_other_things = [record that does not exists]" do
      expect(SomeThing).to receive(:load_fixtures).once.with('some_things').and_return(
        [
          FIRST_THING.merge(
            :some_other_things => ['oh-no-i-dont-exist']
          )
        ]
      )
      SomeThing.seed_model(SomeThing.with_many(:some_other_things, :name))

      expect(SomeThing.first.some_other_things).to eq([])
    end

    it "searches some_other_things by guid by default" do
      guid = '77b756e5-4f47-4c57-9aca-e9b269925cdf'

      some_other_thing = SomeOtherThing.new
      some_other_thing.guid = guid
      some_other_thing.save

      expect(SomeThing).to receive(:load_fixtures).once.with('some_things').and_return(
        [
          FIRST_THING.merge(
            :some_other_things => [guid]
          )
        ]
      )
      SomeThing.seed_model(SomeThing.with_many(:some_other_things))

      expect(SomeThing.first.some_other_things.first).to eq(SomeOtherThing.first)
    end

    it "searches some_other_things by requested keys too" do
      name = 'mike'

      some_other_thing = SomeOtherThing.new
      some_other_thing.name = name
      some_other_thing.save

      expect(SomeThing).to receive(:load_fixtures).once.with('some_things').and_return(
        [
          FIRST_THING.merge(
            :some_other_things => [name]
          )
        ]
      )
      SomeThing.seed_model(SomeThing.with_many(:some_other_things, :name))

      expect(SomeThing.first.some_other_things.first).to eq(SomeOtherThing.first)
    end

    it "uses add proc to add some_other_things" do
      name = 'mike'.freeze

      some_other_thing = SomeOtherThing.new
      some_other_thing.name = name
      some_other_thing.save

      expect(SomeThing).to receive(:load_fixtures).once.with('some_things').and_return(
        [
          FIRST_THING.merge(
            :some_other_things => [name]
          )
        ]
      )
      calls = 0
      SomeThing.seed_model(SomeThing.with_many(:some_other_things, :name, ->(_st, _sot) { calls += 1 }))
      expect(calls).to eq(1)
    end
  end

  context "has one" do
    before do
      SomeThing.class_eval do
        has_one :some_other_thing
      end
    end

    it "seeds something with :some_other_thing missing" do
      expect(SomeThing).to receive(:load_fixtures).once.with('some_things').and_return([FIRST_THING])

      SomeThing.seed_model(SomeThing.with_one(:some_other_thing, :name))

      expect(SomeThing.first.some_other_thing).to eq(nil)
    end

    it "seeds something with :some_other_thing = nil" do
      expect(SomeThing).to receive(:load_fixtures).once.with('some_things').and_return(
        [
          FIRST_THING.merge(
            :some_other_thing => nil
          )
        ]
      )
      SomeThing.seed_model(SomeThing.with_one(:some_other_thing, :name))

      expect(SomeThing.first.some_other_thing).to eq(nil)
    end

    it "seeds something with :some_other_thing = record that does not exists" do
      expect(SomeThing).to receive(:load_fixtures).once.with('some_things').and_return(
        [
          FIRST_THING.merge(
            :some_other_thing => 'oh-no-i-dont-exist'
          )
        ]
      )
      SomeThing.seed_model(SomeThing.with_one(:some_other_thing, :name))

      expect(SomeThing.first.some_other_thing).to eq(nil)
    end

    it "searches associations by guid by default" do
      guid = '77b756e5-4f47-4c57-9aca-e9b269925cdf'

      some_other_thing = SomeOtherThing.new
      some_other_thing.guid = guid
      some_other_thing.save

      expect(SomeThing).to receive(:load_fixtures).once.with('some_things').and_return(
        [
          FIRST_THING.merge(
            :some_other_thing => guid
          )
        ]
      )
      SomeThing.seed_model(SomeThing.with_one(:some_other_thing))

      expect(SomeThing.first.some_other_thing).to eq(SomeOtherThing.first)
    end

    it "searches associations by requested keys too" do
      name = 'mike'

      some_other_thing = SomeOtherThing.new
      some_other_thing.name = name
      some_other_thing.save

      expect(SomeThing).to receive(:load_fixtures).once.with('some_things').and_return(
        [
          FIRST_THING.merge(
            :some_other_thing => name
          )
        ]
      )
      SomeThing.seed_model(SomeThing.with_one(:some_other_thing, :name))

      expect(SomeThing.first.some_other_thing).to eq(SomeOtherThing.first)
    end
  end
end
