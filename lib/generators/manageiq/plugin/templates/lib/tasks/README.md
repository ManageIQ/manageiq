Tasks (.rake files) in this directory will be available as public tasks in the main
ManageIQ app. They can be executed in the plugin gem via the app: namespace

```shell
bin/rails app:<task>
```

Since these tasks are public, please namespace them, as in the following example:

```ruby
namespace <%= rake_task_namespace %> do
  desc "Explaining what the task does"
  task :your_task do
    # Task goes here
  end
end
```

Tasks places in the lib/tasks_private directory will be private to the plugin
and not available in the ManageIQ app.
