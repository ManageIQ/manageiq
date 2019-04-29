Tasks (.rake files) in this directory will be available in the main ManageIQ app.
They can be executed in the plugin gem via the app: namespace

bin/rails app:<task>

Tasks private to the plugin should go into lib/tasks/tasks_private.
