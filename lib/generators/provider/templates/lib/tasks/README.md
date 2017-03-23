Tasks (.rake files) in this directory will be available in the main ManageIQ app.
They can be executed in the provider gem via the app: namespace

bin/rails app:<task>

Task private to the provider should go into lib/tasks/tasks_private.
