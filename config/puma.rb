# This configuration file will be evaluated by Puma. The top-level methods that
# are invoked here are part of Puma's configuration DSL. For more information
# about methods provided by the DSL, see https://puma.io/puma/Puma/DSL.html.

positive_integer_env = lambda do |name, default|
  value = Integer(ENV.fetch(name, default))
  raise ArgumentError, "#{name} must be >= 1" if value < 1

  value
end

# Puma can serve each request in a thread from an internal thread pool.
# The `threads` method setting takes two numbers: a minimum and maximum.
# Any libraries that use thread pools should be configured to match
# the maximum value specified for Puma. Default is set to 5 threads for minimum
# and maximum; this matches the default thread size of Active Record.
max_threads_count = positive_integer_env.call("RAILS_MAX_THREADS", 5)
min_threads_count = positive_integer_env.call("RAILS_MIN_THREADS", max_threads_count)
threads min_threads_count, max_threads_count

if ENV["RAILS_ENV"] == "production"
  worker_count = positive_integer_env.call("WEB_CONCURRENCY", 1)
  workers worker_count if worker_count > 1

  puts "Puma configuration: WEB_CONCURRENCY=#{worker_count}, " \
       "RAILS_MIN_THREADS=#{min_threads_count}, " \
       "RAILS_MAX_THREADS=#{max_threads_count}, " \
       "DB_POOL_PER_PROCESS=#{max_threads_count}, " \
       "MAX_DB_CONNECTIONS=#{worker_count * max_threads_count}"
end

# Specifies the `worker_timeout` threshold that Puma will use to wait before
# terminating a worker in development environments.
worker_timeout 3600 if ENV.fetch("RAILS_ENV", "development") == "development"

# Specifies the `port` that Puma will listen on to receive requests; default is 3000.
port ENV.fetch("PORT") { 3000 }

# Specifies the `environment` that Puma will run in.
environment ENV.fetch("RAILS_ENV") { "development" }

# Specifies the `pidfile` that Puma will use.
pidfile ENV.fetch("PIDFILE") { "tmp/pids/server.pid" }

# Allow puma to be restarted by `bin/rails restart` command.
plugin :tmp_restart
