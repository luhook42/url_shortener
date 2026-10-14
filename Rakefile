# frozen_string_literal: true

require 'sinatra/activerecord/rake'
require 'rake/testtask'
require_relative 'app'

namespace :db do
  desc 'Seed links for load testing'
  task seed_load_test: :environment do
    require 'json'
    require 'securerandom'

    codes = []
    5000.times do
      link = Link.create!(short_code: generate_code, long_url: "https://example.com/#{SecureRandom.hex(4)}")
      codes << link.short_code
    end

    File.write('codes.json', codes.to_json)
    puts "Seeded #{codes.size} links -> codes.json"
  end
end

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
end
