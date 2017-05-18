describe RssFeed::ImportExport do
  it "#export_to_array" do
    expect(FactoryGirl.create(:rss_feed, :title => "Latest things!!!")
      .export_to_array.first["RssFeed"]["title"]).to eq("Latest things!!!")
  end
end
