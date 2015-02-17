require_relative 'spec_helper'

describe ManageiqForeman::PagedResponse do
  describe "#initializer" do
    context "with index hash" do
    end

    context "with array" do
    end

    context "with show hash" do
      let(:paged_response) do
        described_class.new("id" => "the id")
      end

      it "collects the show hash" do
        expect(paged_response.size).to eq(1)
        expect(paged_response.first).to eq("id" => "the id")
      end
    end
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
