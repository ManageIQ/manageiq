class CustomizationTemplateCloudInit < CustomizationTemplate
  DEFAULT_FILENAME = "user-data.txt".freeze

  def default_filename
    DEFAULT_FILENAME
  end
end
