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
    @client.issues("#{user}/#{repo}").map do |issue|
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
    @client.repo_issue_events("#{user}/#{repo}").map do |issue|
      {
        id:             issue[:id],
        timestamp:      issue[:created_at].to_i,
        event:          issue[:event],
        user:           user_details(issue[:actor])
      }
    end
  end

  def commits(user=@user, repo=@repo)
    @client.commits("#{user}/#{repo}").map(&method(:parse_commit))
  end

  def pull_commits(user=@user, repo=@repo, number)
    @client.pull_commits("#{user}/#{repo}", number).map(&method(:parse_commit))
  end

  def pulls_and_forks(user=@user, repo=@repo)
    forks = []
    pulls = []
    fork_commits = []
    @client.pull_requests("#{user}/#{repo}", state: "all").map do |pull|
      #binding.pry
      pulls << {
        event:          "pull",
        id:             pull[:id],
        timestamp:      pull[:created_at].to_i,
        user:           user_details(pull[:user]),
        pull_number:    pull[:number]
      }

      if pull[:state] == "open"
        fork_commits.concat pull_commits(user, repo, pull[:number])
      end

      fork = pull[:head][:repo]
      forks << {
        event:          "fork",
        id:             fork[:id],
        name:           fork[:full_name],
        timestamp:      fork[:created_at].to_i
      }
    end

    [pulls, fork_commits, forks].reduce(:concat)
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

  def parse_commit(commit)
    {
      event:            "commit",
      sha:              commit[:sha],
      user:             commit_user_details(commit[:author], commit[:commit][:author]),
      timestamp:        commit[:commit][:author][:date].to_i,
      message:          commit[:commit][:message]
    }
  end
end

fetcher = GitHubEventsFetcher.new("arrayjam", "tilelive_server", :access_token => ENV["GITHUB_PERSONAL_ACCESS_TOKEN"])
time = Time.now
ap [fetcher.issues, fetcher.issues_events, fetcher.commits, fetcher.pulls_and_forks].reduce(:concat).sort {|x, y| x[:timestamp] <=> y[:timestamp]}
#ap fetcher.commits
#ap fetcher.pulls_and_forks

ap Time.now - time
