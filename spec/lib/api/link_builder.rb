RSpec.describe Api::LinkBuilder do
  describe ".links" do
    let(:href) { "/api/vms?filter[]=name='aa'&offset=foo" }

    it 'returns the correct links' do
      offsets = { "offset" => 0, "limit" => 2 }
      link_builder = Api::LinkBuilder.new(offsets, create_href(offsets), :count => 7, :subcount => 2)
      links = link_builder.links
      expect(links.keys).to eq([:self, :next, :last])
      expect(links[:self]).to eq(create_href(offsets))
      expect(links[:next]).to eq(create_href("offset" => 2, "limit" => 2))
      expect(links[:last]).to eq(create_href("offset" => 6, "limit" => 2))

      offsets = { "offset" => 2, "limit" => 2 }
      link_builder = Api::LinkBuilder.new(offsets, create_href(offsets), :count => 7, :subcount => 2)
      links = link_builder.links
      expect(links.keys).to eq([:self, :next, :previous, :first, :last])
      expect(links[:self]).to eq(create_href(offsets))
      expect(links[:next]).to eq(create_href("offset" => 4, "limit" => 2))
      expect(links[:previous]).to eq(create_href("offset" => 0, "limit" => 2))
      expect(links[:first]).to eq(create_href("offset" => 0, "limit" => 2))
      expect(links[:last]).to eq(create_href("offset" => 6, "limit" => 2))

      offsets = { "offset" => 3, "limit" => 2 }
      link_builder = Api::LinkBuilder.new(offsets, create_href(offsets), :count => 7, :subcount => 2, :subquery_count => 3)
      links = link_builder.links
      expect(links.keys).to eq([:self, :previous, :first])
      expect(links[:self]).to eq(create_href(offsets))
      expect(links[:previous]).to eq(create_href("offset" => 1, "limit" => 2))
      expect(links[:first]).to eq(create_href("offset" => 0, "limit" => 2))

      offsets = { "offset" => 0, "limit" => 3 }
      link_builder = Api::LinkBuilder.new(offsets, create_href(offsets), :count => 7, :subcount => 2, :subquery_count => 3)
      links = link_builder.links
      expect(links.keys).to eq([:self])
      expect(links[:self]).to eq(create_href(offsets))

      offsets = { "offset" => 0, "limit" => 2 }
      link_builder = Api::LinkBuilder.new(offsets, create_href(offsets), :count => 7, :subcount => 2, :subquery_count => 3)
      links = link_builder.links
      expect(links.keys).to eq([:self, :next, :last])
      expect(links[:self]).to eq(create_href(offsets))
      expect(links[:next]).to eq(create_href("offset" => 2, "limit" => 2))
      expect(links[:last]).to eq(create_href("offset" => 2, "limit" => 2))

      offsets = { "offset" => 2, "limit" => 2 }
      link_builder = Api::LinkBuilder.new(offsets, create_href(offsets), :count => 7, :subcount => 2, :subquery_count => 3)
      links = link_builder.links
      expect(links.keys).to eq([:self, :previous, :first])
      expect(links[:self]).to eq(create_href(offsets))
      expect(links[:previous]).to eq(create_href("offset" => 0, "limit" => 2))
      expect(links[:first]).to eq(create_href("offset" => 0, "limit" => 2))
    end
  end

  describe ".pages" do
    it "correctly returns the number of pages" do
      offsets = { "offset" => 0, "limit" => 2 }
      link_builder = Api::LinkBuilder.new(offsets, create_href(offsets), :count => 7, :subcount => 2)
      expect(link_builder.pages).to eq(4)

      link_builder = Api::LinkBuilder.new(offsets, create_href(offsets), :subquery_count => 2, :subcount => 2, :count => 7)
      expect(link_builder.pages).to eq(1)

      link_builder = Api::LinkBuilder.new(offsets, create_href(offsets), :subquery_count => 0, :subcount => 2, :count => 7)
      expect(link_builder.pages).to eq(0)

      offsets = { "offset" => 0, "limit" => 3 }
      link_builder = Api::LinkBuilder.new(offsets, create_href(offsets), :count => 6, :subcount => 3)
      expect(link_builder.pages).to eq(2)
    end
  end

  def create_href(offsets)
    "/api/vms?filter[]=name='aa'&offset=#{offsets["offset"]}&limit=#{offsets["limit"]}"
  end
end
