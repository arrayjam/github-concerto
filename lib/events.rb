require "dotenv"
require "awesome_print"
Dotenv.load

class GitHubEventsFetcher
  require "octokit"
  require "faraday-http-cache"

  def initialize(user, repo_name, auth)
    @user = user
    @repo_name = repo_name
    @repo = "#{user}/#{repo_name}"

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

  def repository(repo=@repo)
    r = @client.repository(repo)
    [{
      event:            "create_repo",
      name:             r[:full_name],
      user:             user_details(r[:owner]),
      timestamp:        r[:created_at].to_i,
      homepage:         r[:homepage],
      description:      r[:description]
    }]
  end

  def issues(repo=@repo)
    @client.issues(repo).map do |issue|
      {
        id:             issue[:id],
        issue_number:   issue[:number],
        timestamp:      issue[:created_at].to_i,
        event:          "opened",
        user:           user_details(issue[:user])
      }
    end
  end

  def issues_events(repo=@repo)
    @client.repo_issue_events(repo).map do |issue|
      {
        id:             issue[:id],
        timestamp:      issue[:created_at].to_i,
        event:          issue[:event],
        user:           user_details(issue[:actor])
      }
    end
  end

  def commits(repo=@repo)
    @client.commits(repo).map(&method(:parse_commit))
  end

  def pull_commits(repo=@repo, number)
    @client.pull_commits(repo, number).map(&method(:parse_commit))
  end

  def pulls_and_forks(repo=@repo)
    forks = []
    pulls = []
    fork_commits = []
    @client.pull_requests(repo).map do |pull|
      pulls << {
        event:          "pull",
        id:             pull[:id],
        timestamp:      pull[:created_at].to_i,
        user:           user_details(pull[:user]),
        pull_number:    pull[:number]
      }

      if pull[:state] == "open"
        fork_commits.concat pull_commits(repo, pull[:number])
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

  def pull_comments(repo=@repo)
    @client.pull_requests_comments(repo).map do |comment|
      {
        id:             comment[:id],
        user:           user_details(comment[:user]),
        timestamp:      comment[:created_at].to_i,
        pull_number:    comment[:pull_request_url][/\d+$/].to_i
      }
    end
  end

  private
  def user_details(user)
    {
      login:            user[:login],
      id:               user[:id],
      avatar_url:       user[:avatar_url],
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

fetcher = GitHubEventsFetcher.new("arrayjam", "github-concerto", :access_token => ENV["GITHUB_PERSONAL_ACCESS_TOKEN"])
time = Time.now
#ap [fetcher.repository, fetcher.issues, fetcher.issues_events, fetcher.commits, fetcher.pulls_and_forks].reduce(:concat).sort {|x, y| x[:timestamp] <=> y[:timestamp]}
#ap fetcher.repository
#ap fetcher.commits
#ap fetcher.pulls_and_forks
ap fetcher.pull_comments

ap Time.now - time
