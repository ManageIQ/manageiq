require "awesome_spawn"

RSpec.describe "I18n" do
  Rails.root.glob("locale/**/*.po").sort.each do |po_file|
    po_file = po_file.relative_path_from(Rails.root)

    # This test verifies that msgfmt succeeds on each .po, since during
    # build we run msgfmt on each file to convert it to an .mo file for
    # efficient delivery
    it "msgfmt on #{po_file} succeeds" do
      skip("msgfmt is not installed") unless system("which msgfmt > /dev/null")

      result = AwesomeSpawn.run("msgfmt #{po_file} --check -o - >/dev/null", :chdir => Rails.root)
      expect(result.success?).to be_truthy, "msgfmt failed with the following errors:\n\n#{result.error.indent(2)}"
    end
  end
end
