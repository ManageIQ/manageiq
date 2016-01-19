require "spec_helper"

describe Vmdb::Settings::HashDiffer do
  let(:before_hash) do
    {
      :values => {
        :array           => ["val1", "val2"],
        :boolean         => true,
        :empty_hash      => {},
        :int_with_method => "10.minutes",
        :integer         => 10,
        :nil             => nil,
        :non_nil         => "some_value",
        :string          => "some_value",
      },
      :very   => {
        :deeply => {
          :nested => {
            :string => "deep_value"
          }
        }
      }
    }
  end

  let(:after_hash) do
    {
      :values => {
        :array           => ["new val1", "new val2"],
        :boolean         => false,
        :empty_hash      => {"key1" => "x", "key2" => "y"},
        :int_with_method => "20.minutes",
        :integer         => 99,
        :nil             => "not nil",
        :non_existant    => "exists",
        :non_nil         => "not nil",
        :string          => "new value",
      },
      :very   => {
        :deeply => {
          :nested => {
            :string => "new value"
          }
        }
      }
    }
  end

  it ".changes" do
    expect(described_class.changes(before_hash, after_hash)).to eq [
      {:key => "/values/array",              :value => ["new val1", "new val2"]},
      {:key => "/values/boolean",            :value => false},
      {:key => "/values/empty_hash/key1",    :value => "x"},
      {:key => "/values/empty_hash/key2",    :value => "y"},
      {:key => "/values/int_with_method",    :value => "20.minutes"},
      {:key => "/values/integer",            :value => 99},
      {:key => "/values/nil",                :value => "not nil"},
      {:key => "/values/non_nil",            :value => "not nil"},
      {:key => "/values/string",             :value => "new value"},
      {:key => "/values/non_existant",       :value => "exists"},
      {:key => "/very/deeply/nested/string", :value => "new value"}
    ]
  end

  it ".diff_hashes" do
    expect(described_class.diff_hashes(before_hash, after_hash)).to eq(
      :values => {
        :array           => [["val1", "val2"], ["new val1", "new val2"]],
        :boolean         => [true, false],
        :empty_hash      => {
          "key1" => [described_class::MissingKey, "x"],
          "key2" => [described_class::MissingKey, "y"]
        },
        :int_with_method => ["10.minutes", "20.minutes"],
        :integer         => [10, 99],
        :nil             => [nil, "not nil"],
        :non_nil         => ["some_value", "not nil"],
        :string          => ["some_value", "new value"],
        :non_existant    => [described_class::MissingKey, "exists"]
      },
      :very => {
        :deeply => {
          :nested => {
            :string => ["deep_value", "new value"]
          }
        }
      }
    )
  end
end
