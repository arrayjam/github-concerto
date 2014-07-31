require "sinatra"
require "./lib/events"
require "dotenv"

Dotenv.load

get "/" do
  erb :index
end

get "/events" do
  GitHubEventsFetcher.new("arrayjam", "github-concerto", :access_token => ENV["GITHUB_PERSONAL_ACCESS_TOKEN"])
end
