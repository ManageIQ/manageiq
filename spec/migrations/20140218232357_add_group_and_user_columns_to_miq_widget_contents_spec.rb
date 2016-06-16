require_migration

describe AddGroupAndUserColumnsToMiqWidgetContents do
  shared_examples "removing widget contents" do
    let(:miq_widget_content_stub) { migration_stub(:MiqWidgetContent) }

    it "removes all existing widget content" do
      miq_widget_content_stub.create!

      migrate

      expect(miq_widget_content_stub.all).to be_empty
    end
  end

  migration_context :up do
    include_examples "removing widget contents"
  end

  migration_context :down do
    include_examples "removing widget contents"
  end
end
