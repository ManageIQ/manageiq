RSpec.describe DialogFieldImporter do
  let(:dialog_field_importer) { described_class.new }

  describe "#import_field" do
    let(:dialog_field) do
      {
        "type"                    => type,
        "name"                    => "Something",
        "label"                   => "Something else",
        "resource_action"         => resource_action,
        "options"                 => options,
        "dialog_field_responders" => ["foo_that_gets_ignored"]
      }
    end

    let(:resource_action) do
      {
        "ae_namespace" => "Customer/Sample",
        "ae_class"     => "Methods",
        "ae_instance"  => "Testing"
      }
    end

    let(:options) { nil }

    context "when the type of the dialog field is an old DialogFieldDynamicList" do
      let(:type) { "DialogFieldDynamicList" }

      before do
        @result = dialog_field_importer.import_field(dialog_field)
      end

      it "creates a DialogFieldDropDownList with the correct name" do
        expect(DialogFieldDropDownList.first.name).to eq("Something")
      end

      it "creates a DialogFieldDropDownList with the correct label" do
        expect(DialogFieldDropDownList.first.label).to eq("Something else")
      end

      it "creates a DialogFieldDropDownList with dynamic true" do
        expect(DialogFieldDropDownList.first.dynamic).to be_truthy
      end

      it "creates a ResourceAction with the given attributes" do
        expect(DialogFieldDropDownList.first.resource_action.fqname).to eq("/Customer/Sample/Methods/Testing")
      end

      it "returns the created object" do
        expect(@result).to eq(DialogFieldDropDownList.first)
      end
    end

    context "when the type of the dialog field is included in DIALOG_FIELD_TYPES" do
      let(:type) { "DialogFieldTextBox" }

      it "creates a DialogFieldTextBox with the correct name" do
        dialog_field_importer.import_field(dialog_field)
        expect(DialogFieldTextBox.first.name).to eq("Something")
      end

      it "creates a DialogFieldTextBox with the correct label" do
        dialog_field_importer.import_field(dialog_field)
        expect(DialogFieldTextBox.first.label).to eq("Something else")
      end

      it "creates a ResourceAction with the given attributes" do
        dialog_field_importer.import_field(dialog_field)
        expect(DialogFieldTextBox.first.resource_action.fqname).to eq("/Customer/Sample/Methods/Testing")
      end

      it "returns the created object of that type" do
        result = dialog_field_importer.import_field(dialog_field)
        expect(result).to eq(DialogFieldTextBox.first)
      end
    end

    context "when the type of the dialog field is a tag control" do
      let(:type) { "DialogFieldTagControl" }

      context "when the import file contains a category_name, but no category_id" do
        let(:options) do
          {
            :category_name        => "best_category",
            :category_description => category_description
          }
        end
        let(:category_description) { "best_category" }

        context "when the category exists by name and description" do
          before do
            @existing_category = Category.create!(:name => "best_category", :description => "best_category")
          end

          context "when the category description does not match" do
            let(:category_description) { "worst_category" }

            it "does not assign a category" do
              dialog_field_importer.import_field(dialog_field)
              expect(DialogFieldTagControl.first.category).to eq(nil)
            end
          end

          context "when the category description matches" do
            it "uses the correct category, ignoring id" do
              dialog_field_importer.import_field(dialog_field)
              expect(DialogFieldTagControl.first.category).to eq(@existing_category.id.to_s)
            end
          end
        end

        context "when the category does not exist by name and description" do
          it "does not assign a category" do
            dialog_field_importer.import_field(dialog_field)
            expect(DialogFieldTagControl.first.category).to eq(nil)
          end
        end

        it "creates a DialogFieldTagControl with the correct name" do
          dialog_field_importer.import_field(dialog_field)
          expect(DialogFieldTagControl.first.name).to eq("Something")
        end
      end

      context "when the import file contains a category_id" do
        before do
          @first_category    = Category.create!(:name => "first_category", :description => "first_category")
          @existing_category = Category.create!(:name => "best_category", :description => "best_category")
        end

        let(:options) do
          {
            :category_id          => category_id,
            :category_name        => category_name,
            :category_description => category_description
          }
        end

        context "when the category_id matches an existing category" do
          let(:category_id) { @existing_category.id }

          context "when the category_name matches the existing category" do
            let(:category_name) { @existing_category.name }

            context "when the category_description matches the existing category" do
              let(:category_description) { @existing_category.description }

              it "sets the field to the existing category" do
                dialog_field_importer.import_field(dialog_field)
                expect(DialogFieldTagControl.first.category).to eq(@existing_category.id.to_s)
              end
            end

            context "when the category_description does not match the existing category" do
              let(:category_description) { "worst_description" }

              it "returns nil" do
                dialog_field_importer.import_field(dialog_field)
                expect(DialogFieldTagControl.first.category).to eq(nil)
              end
            end
          end

          context "when the category_name matches a different category" do
            let(:category_name) { @first_category.name }

            context "when the category_description matches the different category" do
              let(:category_description) { @first_category.description }

              it "sets the field to the different category" do
                dialog_field_importer.import_field(dialog_field)
                expect(DialogFieldTagControl.first.category).to eq(@first_category.id.to_s)
              end
            end

            context "when the category_description does not match the existing category" do
              let(:category_description) { "worst_description" }

              it "returns nil" do
                dialog_field_importer.import_field(dialog_field)
                expect(DialogFieldTagControl.first.category).to eq(nil)
              end
            end
          end

          context "when the category_name does not match the existing category" do
            let(:category_name) { "worst_category" }

            context "when the category_description matches the existing category" do
              let(:category_description) { @existing_category.description }

              it "returns nil" do
                dialog_field_importer.import_field(dialog_field)
                expect(DialogFieldTagControl.first.category).to eq(nil)
              end
            end

            context "when the category_description does not match the existing category" do
              let(:category_description) { "worst_description" }

              it "returns nil" do
                dialog_field_importer.import_field(dialog_field)
                expect(DialogFieldTagControl.first.category).to eq(nil)
              end
            end
          end
        end

        context "when the category_id does not match an existing category" do
          let(:category_id) { @existing_category.id + 1 }

          context "when the category_name matches an existing category" do
            let(:category_name) { @existing_category.name }

            context "when the category_description matches the existing category" do
              let(:category_description) { @existing_category.description }

              it "sets the field to the existing category" do
                dialog_field_importer.import_field(dialog_field)
                expect(DialogFieldTagControl.first.category).to eq(@existing_category.id.to_s)
              end
            end

            context "when the category_description does not match the existing category" do
              let(:category_description) { "worst_description" }

              it "returns nil" do
                dialog_field_importer.import_field(dialog_field)
                expect(DialogFieldTagControl.first.category).to eq(nil)
              end
            end
          end

          context "when the category_name does not match the existing category" do
            let(:category_name) { "worst_category" }

            context "when the category_description matches the existing category" do
              let(:category_description) { @existing_category.description }

              it "returns nil" do
                dialog_field_importer.import_field(dialog_field)
                expect(DialogFieldTagControl.first.category).to eq(nil)
              end
            end

            context "when the category_description does not match the existing category" do
              let(:category_description) { "worst_description" }

              it "returns nil" do
                dialog_field_importer.import_field(dialog_field)
                expect(DialogFieldTagControl.first.category).to eq(nil)
              end
            end
          end
        end
      end
    end

    context "when the type of the dialog field is nil" do
      let(:type) { nil }

      it "creates a DialogField with the correct name" do
        dialog_field_importer.import_field(dialog_field)
        expect(DialogField.first.name).to eq("Something")
      end

      it "creates a DialogField with the correct label" do
        dialog_field_importer.import_field(dialog_field)
        expect(DialogField.first.label).to eq("Something else")
      end

      it "returns the created DialogField object" do
        result = dialog_field_importer.import_field(dialog_field)
        expect(result).to eq(DialogField.first)
      end
    end

    context "#visible?" do
      let(:dialog_field) do
        {
          "type"    => "DialogFieldTextBox",
          "name"    => "Something else"
        }
      end

      it "without visible setting defaults to true" do
        dialog_field_importer.import_field(dialog_field)
        expect(DialogField.first.visible?).to eq(true)
      end

      it "false" do
        dialog_field_importer.import_field(dialog_field.merge("visible" => false))
        expect(DialogField.first.visible?).to eq(false)
      end

      it "true" do
        dialog_field_importer.import_field(dialog_field.merge("visible" => true))
        expect(DialogField.first.visible?).to eq(true)
      end
    end

    context "when the type of the dialog field is not included in DIALOG_FIELD_TYPES and not nil" do
      let(:type) { "potato" }

      it "raises an InvalidDialogFieldTypeError" do
        expect do
          dialog_field_importer.import_field(dialog_field)
        end.to raise_error(DialogFieldImporter::InvalidDialogFieldTypeError)
      end
    end

    context "version migrations" do
      let(:type) { "DialogFieldDynamicList" }
      let(:dialog_field_show_false) do
        dialog_field.merge('show_refresh_button' => false,
                           'load_values_on_init' => false)
      end
      let(:dialog_field_load_false) do
        dialog_field.merge('show_refresh_button' => true,
                           'load_values_on_init' => false)
      end

      context "from version 1" do
        context "load_values_on_init" do
          it "is set to true when no refresh button" do
            dialog_field_importer.import_field(dialog_field_show_false, DialogImportService::DEFAULT_DIALOG_VERSION)
            expect(DialogField.first.load_values_on_init).to eq(true)
          end

          it "is preserved when refresh button" do
            dialog_field_importer.import_field(dialog_field_load_false, DialogImportService::DEFAULT_DIALOG_VERSION)
            expect(DialogField.first.load_values_on_init).to eq(false)
          end
        end
      end

      context "from current version" do
        context "load_values_on_init" do
          it "is not touched" do
            dialog_field_importer.import_field(dialog_field_show_false)
            expect(DialogField.first.load_values_on_init).to eq(false)
          end
        end
      end
    end
  end
end
