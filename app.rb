# frozen_string_literal: true

require 'connection_pool'
require 'redis'
require 'sinatra'
require 'sinatra/activerecord'
require_relative 'models/link'

set :database_file, 'config/database.yml' # we'll add this file next

CODE_CHARS = [*'a'..'z', *'A'..'Z', *'0'..'9'].freeze

module RedisPool
  def self.pool
    @pool ||= ConnectionPool.new(size: 16, timeout: 5) { Redis.new }
  end

  def self.reset!
    @pool&.shutdown { |conn| conn.close }
    @pool = ConnectionPool.new(size: 16, timeout: 5) { Redis.new }
  end
end

def generate_code(length = 7)
  Array.new(length) { CODE_CHARS.sample }.join
end

get '/:code' do
  code = params['code']
  cache_key = "link:#{code}"

  cached_url = RedisPool.pool.with { |redis| redis.get(cache_key) }
  if cached_url
    puts "cache HIT for #{code}"
    redirect cached_url, 301
  else
    puts "cache MISS for #{code}, querying postgres"
    link = Link.find_by(short_code: code)
    halt 404, 'not found' unless link

    RedisPool.pool.with { |redis| redis.set(cache_key, link.long_url) }
    redirect link.long_url, 301
  end
end

post '/links' do
  long_url = params['url']
  halt 400, 'missing url' unless long_url

  link = nil
  loop do
    link = Link.create!(short_code: generate_code, long_url: long_url)
    break
  rescue ActiveRecord::RecordNotUnique
    next # collided, try another random code
  end

  "short link: /#{link.short_code}"
end

put '/links/:code' do
  code = params['code']
  link = Link.find_by(short_code: code)
  halt 404, 'not found' unless link

  new_url = params['url']
  halt 400, 'missing url' unless new_url

  link.update!(long_url: new_url)
  RedisPool.pool.with { |redis| redis.del("link:#{code}") }

  "updated: /#{link.short_code} -> #{new_url}"
end
