port 4567
workers 2
threads 5, 16

before_worker_boot do
  RedisPool.reset!
end
