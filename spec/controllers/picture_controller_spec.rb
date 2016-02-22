describe PictureController do
  let(:picture_content) { "BINARY IMAGE CONTENT" }
  let(:picture) { FactoryGirl.create(:picture, :id => 10_000_000_000_005, :extension => "jpg") }

  before do
    set_user_privileges

    EvmSpecHelper.create_guid_miq_server_zone

    picture.content = picture_content.dup # dup because destructive operation
    picture.save
  end

  it 'can serve a picture directly from the database' do
    get :show, :params => { :basename => "#{picture.compressed_id}.#{picture.extension}" }
    expect(response.status).to eq(200)
    expect(response.body).to eq(picture_content)
  end

  it 'can serve a picture directly from the database using the uncompressed id' do
    get :show, :params => { :basename => "#{picture.compressed_id}.#{picture.extension}" }
    expect(response.status).to eq(200)
    expect(response.body).to eq(picture_content)
  end

  it "responds with a Not Found with pictures of incorrect extension" do
    get :show, :params => { :basename => "#{picture.compressed_id}.png" }
    expect(response.status).to eq(404)
    expect(response.body).to be_blank
  end

  it "responds with a Not Found with unknown pictures" do
    get :show, :params => { :basename => "bogusimage.gif" }
    expect(response.status).to eq(404)
    expect(response.body).to be_blank
  end
end
