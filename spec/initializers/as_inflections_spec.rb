describe String, "inflections" do
  {
    "base" => "bases",
  }.each do |singular, plural|
    example("#pluralize")   { expect(singular.pluralize).to eq(plural) }
    example("#singularize") { expect(plural.singularize).to eq(singular) }
  end
end
