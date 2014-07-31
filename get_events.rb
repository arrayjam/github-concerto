require "octokit"
require "faraday-http-cache"
require "dotenv"
require "json"

Dotenv.load

stack = Faraday::RackBuilder.new do |builder|
  builder.use Faraday::HttpCache
  builder.response :logger
  builder.use Octokit::Response::RaiseError
  builder.adapter Faraday.default_adapter
end
Octokit.middleware = stack

Octokit.auto_paginate = true

client = Octokit::Client.new :access_token => ENV["GITHUB_PERSONAL_ACCESS_TOKEN"]

p client.user_events("arrayjam").length

#puts client.user_events("arrayjam").map {|e| "#{e[:repo][:name]}: #{e[:type]}"}
