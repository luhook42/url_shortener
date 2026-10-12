# frozen_string_literal: true

require 'connection_pool'
require 'rack/cors'
require 'redis'
require 'sinatra'
require 'sinatra/activerecord'
require_relative 'models/link'

use Rack::Cors do
  allow do
    origins 'http://localhost:5173'
    resource '/*', headers: :any, methods: %i[get post put delete options]
  end
end

set :database_file, 'config/database.yml'

CODE_CHARS = [*'a'..'z', *'A'..'Z', *'0'..'9'].freeze

module RedisPool
  def self.pool
    @pool ||= ConnectionPool.new(size: 16, timeout: 5) do
      Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379'))
    end
  end

  def self.reset!
    @pool&.shutdown { |conn| conn.close }
    @pool = ConnectionPool.new(size: 16, timeout: 5) do
      Redis.new(url: ENV.fetch('REDIS_URL', 'redis://localhost:6379'))
    end
  end
end

def generate_code(length = 7)
  Array.new(length) { CODE_CHARS.sample }.join
end

get '/links' do
  content_type :json
  Link.order(created_at: :desc).to_json
end

get '/:code' do
  code = params['code']
  cache_key = "link:#{code}"

  headers['Cache-Control'] = 'no-cache'

  cached_url = RedisPool.pool.with { |redis| redis.get(cache_key) }
  if cached_url
    puts "cache HIT for #{code}"
    redirect cached_url, 302
  else
    puts "cache MISS for #{code}, querying postgres"
    link = Link.find_by(short_code: code)
    halt 404, 'not found' unless link

    RedisPool.pool.with { |redis| redis.set(cache_key, link.long_url) }
    redirect link.long_url, 302
  end
end

post '/links' do
  content_type :json
  long_url = params['url']
  halt 400, { error: 'missing url' }.to_json unless long_url

  link = nil
  loop do
    link = Link.create!(short_code: generate_code, long_url: long_url)
    break
  rescue ActiveRecord::RecordNotUnique
    next
  end

  status 201
  link.to_json
end

put '/links/:code' do
  content_type :json
  code = params['code']
  link = Link.find_by(short_code: code)
  halt 404, { error: 'not found' }.to_json unless link

  new_url = params['url']
  halt 400, { error: 'missing url' }.to_json unless new_url

  link.update!(long_url: new_url)
  RedisPool.pool.with { |redis| redis.del("link:#{code}") }

  link.to_json
end
