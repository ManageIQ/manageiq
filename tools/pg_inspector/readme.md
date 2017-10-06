pg_inspector readme
===================

pg_inspector is a tool to inspect ManageIQ process caused deadlock or long time blocking in PostgreSQL. pg_inpector inspects database in four steps. You can run `pg_inspector.rb -h` to see all steps, which are displayed in `Operations` section. For each step, you can see its specific options by `pg_inspector.rb operation -h`.

Step 1: dump active connections to YAML file
--------------------------------------------

Run `pg_inspector.rb connections`, and will dump current `pg_stat_activity` to a YAML file. It will also dump `pg_locks`. Database password should be given in either a file using `-f` option or PGPASSWORD environment variable.

It by default use `postgres` user to login local postgres server, and will ask you for password. If your database setting doesn't need a password, you can leave it as empty. The output connection file is `pg_inspector/output/active_connections.yml` by default, and lock file is `pg_inspector/output/locks.yml`. You can connect to a different database host by `-s` option, using a different user by `-u` option, and output to different place by `-o` for active connections, `-l` for locks. But default settings and empty password should be sufficient to run in master node of appliance. This dump operation can be run even after database get blocked, so this can be run only when blocking happens.

Step 2: dump ManageIQ server information to YAML file
-----------------------------------------------------

Run `pg_inspector.rb servers` will dump ManageIQ server information in a YAML file. Database password is given in the same way as step 1. The YAML file is by default `pg_inspector/output/server_MM-DD-YYYY_HH:MM:SS.yml`, and a symlink `pg_inspector/output/server.yml` will be linked to the newest server dump file.

You can give host, user, output name options the same way as step 1. This step can't be dump when postgres server blocked, so you need to run it periodically to get (hopefully) up to date dump file.

Step 3: Combine connections and servers information to human readable format
----------------------------------------------------------------------------

Run `pg_inspector.rb human` will combine information gathered from step 1 and step 2 to a human readable YAML file. It doesn't require database access.

The output file will by default as `pg_inspector/output/human.yml`. It has four sections: servers, workers, connections and other_processes.

Step 4: Combine human.yml file and lock file
--------------------------------------------

Run `pg_inspector.rb locks` will combine lock output from step 1 and human.yml from step3. It doesn't require database access.

The output file will by default as `pg_inspector/output/locks_output.yml`. The file organization will be same as step 3, but each connection has a `blocked_by` property indicate it's blocked by which connection.

After four steps
----------------

These four steps are included and can be run in customer's appliance. We can do further analysis such as generating and viewing lock graphs from step 4's output. Because this has external dependency which is not revelant to appliance, it's in a separate place.



