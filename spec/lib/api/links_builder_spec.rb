RSpec.describe Api::LinksBuilder do
  describe "#links" do
    it "returns only self, next, and last links when it is the first page" do
      offsets = { "offset" => 0, "limit" => 2 }
      counts = Api::QueryCounts.new(7, 2)
      link_builder = Api::LinksBuilder.new(offsets, create_href(offsets), counts)
      links = link_builder.links
      expect(links.keys).to eq([:self, :next, :last])
      expect(links[:self]).to eq(create_href(offsets))
      expect(links[:next]).to eq(create_href("offset" => 2, "limit" => 2))
      expect(links[:last]).to eq(create_href("offset" => 6, "limit" => 2))
    end

    it "returns all of the links if it is a middle page" do
      offsets = { "offset" => 2, "limit" => 2 }
      counts = Api::QueryCounts.new(7, 2)
      link_builder = Api::LinksBuilder.new(offsets, create_href(offsets), counts)
      links = link_builder.links

      expect(links.keys).to eq([:self, :next, :previous, :first, :last])
      expect(links[:self]).to eq(create_href(offsets))
      expect(links[:next]).to eq(create_href("offset" => 4, "limit" => 2))
      expect(links[:previous]).to eq(create_href("offset" => 0, "limit" => 2))
      expect(links[:first]).to eq(create_href("offset" => 0, "limit" => 2))
      expect(links[:last]).to eq(create_href("offset" => 6, "limit" => 2))
    end

    it "returns only self, previous, and first if it is the last page" do
      offsets = { "offset" => 3, "limit" => 2 }
      counts = Api::QueryCounts.new(7, 2, 3)
      link_builder = Api::LinksBuilder.new(offsets, create_href(offsets), counts)
      links = link_builder.links
      expect(links.keys).to eq([:self, :previous, :first])
      expect(links[:self]).to eq(create_href(offsets))
      expect(links[:previous]).to eq(create_href("offset" => 1, "limit" => 2))
      expect(links[:first]).to eq(create_href("offset" => 0, "limit" => 2))
    end

    it "returns only self it is the only page" do
      offsets = { "offset" => 0, "limit" => 3 }
      counts = Api::QueryCounts.new(7, 3, 3)
      link_builder = Api::LinksBuilder.new(offsets, create_href(offsets), counts)
      links = link_builder.links
      expect(links.keys).to eq([:self])
      expect(links[:self]).to eq(create_href(offsets))
    end
  end

  describe "#pages" do
    let(:offsets) { { "offset" => 0, "limit" => 2 } }

    it "returns correct page count when last page count is less than the limit" do
      counts = Api::QueryCounts.new(7, 2)
      link_builder = Api::LinksBuilder.new(offsets, create_href(offsets), counts)
      expect(link_builder.pages).to eq(4)
    end

    it "returns correct page count when there is only one page" do
      counts = Api::QueryCounts.new(7, 2, 2)
      link_builder = Api::LinksBuilder.new(offsets, create_href(offsets), counts)
      expect(link_builder.pages).to eq(1)
    end

    it "returns correct page count when there are no subquery results" do
      counts = Api::QueryCounts.new(7, 2, 0)
      link_builder = Api::LinksBuilder.new(offsets, create_href(offsets), counts)
      expect(link_builder.pages).to eq(0)
    end

    it "returns the correct page count when last page count is equal to the limit" do
      offsets = { "offset" => 0, "limit" => 3 }
      counts = Api::QueryCounts.new(6, 3)
      link_builder = Api::LinksBuilder.new(offsets, create_href(offsets), counts)
      expect(link_builder.pages).to eq(2)
    end
  end

  def create_href(offsets)
    "/api/vms?filter[]=name='aa'&offset=#{offsets["offset"]}&limit=#{offsets["limit"]}"
  end
end
