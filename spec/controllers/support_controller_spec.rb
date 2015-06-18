require "spec_helper"

describe SupportController do
  render_views

  before do
    EvmSpecHelper.create_guid_miq_server_zone
    set_user_privileges
  end

  context "#index" do
    it "renders properly" do
      get :index

      expect(response.status).to eq(200)
      expect(response).to render_template('support/show')
    end

    it "without PDF help documents" do
      get :index

      expect(assigns(:pdf_documents)).to be_empty
    end

    it "with PDF help documents" do
      doc_path = Rails.root.join("public/doc")
      allow(controller).to receive(:pdf_document_files).and_return(
        [
          doc_path.join("help_doc_1.pdf").to_s,
          doc_path.join("another_support_document.pdf").to_s,
        ]
      )

      get :index

      expect(assigns(:pdf_documents)).to eq(
        "help_doc_1"               => "Help Doc 1",
        "another_support_document" => "Another Support Document"
      )
    end
  end
end
