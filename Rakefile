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

namespace :users do
  # The password is read from a hidden prompt (or piped on stdin), never from
  # the command line, so it stays out of shell history and the process list.
  desc 'Create a user: rake users:create EMAIL=you@example.com'
  task create: 'db:environment' do
    require 'io/console'

    email = ENV.fetch('EMAIL') { abort 'Usage: rake users:create EMAIL=you@example.com' }

    password =
      if $stdin.tty?
        first = $stdin.getpass('Password: ')
        abort 'Passwords did not match.' unless $stdin.getpass('Confirm password: ') == first
        first
      else
        $stdin.gets.to_s.chomp
      end
    abort 'Password must be at least 12 characters.' if password.length < 12

    user = User.new(email: email, password: password)
    abort "Could not create user: #{user.errors.full_messages.join(', ')}" unless user.save

    puts "Created user #{user.email} (id #{user.id})"
  end
end

Rake::TestTask.new(:test) do |t|
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
end
