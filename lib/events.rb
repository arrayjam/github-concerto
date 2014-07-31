require "dotenv"
require "awesome_print"
Dotenv.load

class GitHubEventsFetcher
  require "octokit"
  require "faraday-http-cache"

  def initialize(user, repo, auth)
    @user = user
    @repo = repo
    @client = Octokit::Client.new(auth)

    stack = Faraday::RackBuilder.new do |builder|
      builder.use Faraday::HttpCache
      builder.response :logger
      builder.use Octokit::Response::RaiseError
      builder.adapter Faraday.default_adapter
    end
    Octokit.middleware = stack

    Octokit.auto_paginate = true
  end

  def issues(user=@user, repo=@repo)
    all_issues = @client.issues "#{user}/#{repo}"
    all_issues.map do |issue|
      {
        id:             issue[:id],
        issue_number:   issue[:number],
        timestamp:      issue[:created_at].to_i,
        event:          "opened",
        user:           user_details(issue[:user])
      }
    end
  end

  def issues_events(user=@user, repo=@repo)
    all_issues = @client.repo_issue_events "#{user}/#{repo}"
    all_issues.map do |issue|
      {
        id:             issue[:id],
        timestamp:      issue[:created_at].to_i,
        event:          issue[:event],
        user:           user_details(issue[:actor])
      }
    end
  end

  def commits(user=@user, repo=@repo)
    all_commits = @client.commits "#{user}/#{repo}"
    all_commits.map do |commit|
      {
        sha:            commit[:sha],
        author:         commit_user_details(commit[:author], commit[:commit][:author]),
        timestamp:      commit[:commit][:author][:date].to_i
      }
    end
  end

  private
  def user_details(user)
    {
      login:            user[:login],
      id:               user[:id],
      avatar_url:       user[:avatar_url]
    }
  end

  def commit_user_details(user, commit_user)
    {
      login:            user[:login],
      id:               user[:id],
      avatar_url:       user[:avatar_url],
      name:             commit_user[:name],
      email:            commit_user[:email]
    }
  end
end

fetcher = GitHubEventsFetcher.new("arrayjam", "github-concerto", :access_token => ENV["GITHUB_PERSONAL_ACCESS_TOKEN"])
#ap fetcher.issues.concat(fetcher.issues_events).sort {|x, y| x[:timestamp] <=> y[:timestamp]}
ap fetcher.commits
