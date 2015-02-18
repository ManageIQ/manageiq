require_relative 'spec_helper'

describe ManageiqForeman::PagedResponse do
  let(:first_page) do
    described_class.new(
      "total"    => 39,
      "subtotal" => 39,
      "page"     => 1,
      "per_page" => 2,
      "search"   => nil,
      "sort"     => {
        "by"    => nil,
        "order" => nil
      },
      "results"  => [
        {"name" => "first", "id" => 1},
        {"name" => "second", "id" => 2}
      ]
    )
  end

  describe "#initializer" do
    context "with index hash" do
      it "creates the result set" do
        expect(first_page.total).to eq(39)
        expect(first_page.size).to eq(2)
        expect(first_page.first).to eq("name" => "first", "id" => 1)
      end
    end

    context "with array" do
      let(:paged_response) do
        described_class.new([{"id" => "1"}, {"id" => "2"}])
      end

      it "creates the result set" do
        expect(paged_response.size).to eq(2)
        expect(paged_response.first).to eq("id" => "1")
      end
    end

    context "with show hash" do
      let(:paged_response) do
        described_class.new("id" => "the id")
      end

      it "creates the result set" do
        expect(paged_response.size).to eq(1)
        expect(paged_response.first).to eq("id" => "the id")
      end
    end
  end

  describe "#empty" do
    it { expect(described_class.new(["id" => 3])).not_to be_empty }
    it { expect(described_class.new([])).to be_empty }
  end

  describe "#map!" do
    let(:paged_response) do
      described_class.new([{"id" => "1"}, {"id" => "2"}, {"id" => "3"}])
    end

    let(:mapped_response) do
      paged_response.map! { |r| {"id" => "a" * r["id"].to_i} }
    end

    it { expect(mapped_response.results).to eq([{"id" => "a"}, {"id" => "aa"}, {"id" => "aaa"}]) }
  end

  describe "comparison" do
    let(:a) { described_class.new([{"id" => "a"}, {"id" => "b"}]) }
    let(:b) { described_class.new([{"id" => "a"}, {"id" => "b"}]) }
    let(:x) { described_class.new([{"id" => "b"}, {"id" => "b"}]) }
    it { expect(a).to eq(a) }
    it { expect(a).to eq(b) }
    it { expect(a).not_to eq(x) }
  end
end
