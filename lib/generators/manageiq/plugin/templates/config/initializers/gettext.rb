Vmdb::Gettext::Domains.add_domain(
  '<%= class_name %>',
  <%= class_name %>::Engine.root.join('locale').to_s,
  :po
)
