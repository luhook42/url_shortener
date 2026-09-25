port 4567
workers 2
threads 5, 16

# ActiveRecord/pg connections (and their underlying TCP sockets + SSL state)
# are not fork-safe: the master process loads app.rb (via Puma's preload)
# and establishes a connection, then forks 2 workers that would otherwise
# inherit that same live socket. Drop it before forking, then open a fresh
# one in each worker -- same pattern already used for RedisPool below.
before_fork do
  ActiveRecord::Base.connection_pool.disconnect! if defined?(ActiveRecord::Base)
end

before_worker_boot do
  ActiveRecord::Base.establish_connection if defined?(ActiveRecord::Base)
  RedisPool.reset!
end
