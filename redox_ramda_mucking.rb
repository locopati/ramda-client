require 'time'
require 'pp'
require './github_gql_client'

PR_COUNT = <<-QUERY
  query {
    ramda: organization(login:"ramda") {
      repositories(first:100) {
        nodes {
          name
          pullRequests {
            totalCount
          }
        }
      }
    }
  }
QUERY


MERGED_AT = <<-QUERY
  query($reponame:String!) {
    repository(owner:"ramda", name:$reponame) {
      pullRequests(first:100) {
        nodes {
          mergedAt
        }
        pageInfo {
          startCursor
          endCursor
          hasNextPage
        }     
      }
    }
  }
QUERY

unless ENV['GITHUB_TOKEN']
  puts 'you must define an environment variable with your github OAuth token'
  exit
end
c = GithubGqlClient.new ENV['GITHUB_TOKEN']

# total number of PRs
rez = c.request PR_COUNT
puts rez
pr_count = rez['ramda']['repositories']['nodes'].reduce(0) { |accum, n| accum += n['pullRequests']['totalCount']}
puts "total number of PRs #{pr_count}"

# PRs merged week-over-week
week_over_week = {}
repo_names =  rez['ramda']['repositories']['nodes'].map { |n| n['name'] }
repo_names.each do |repo_name|
  puts "processing repository... #{repo_name}"
  continue = true
  query = MERGED_AT.dup
  result = {}

  while continue do
    rez = c.request query, reponame: repo_name
    pull_reqs = rez['repository']['pullRequests']
    # ruby hashes are ordered by insertion
    # we'll take an extra step here to extract merge dates and sort them
    # so that we get nicely ordered output at the end
    merged_at = pull_reqs['nodes'].map do | node |
      merged_str = node['mergedAt']
      merged_str ? Time.parse(merged_str) : nil
    end
    merged_at.compact.sort.each do | merged |
      year = merged.year
      weeknum = merged.strftime('%W').to_i # ISO week
      result[year] = result[year] || {}
      result[year][weeknum] = result[year][weeknum] ? result[year][weeknum] + 1 : 1
    end
    query.sub! /pullRequests\(.*\)/, "pullRequests(first:100, after:\"#{pull_reqs['pageInfo']['endCursor']}\")"
    continue = pull_reqs['pageInfo']['hasNextPage']
  end

  week_over_week[repo_name] = result
end

puts 'number of merges by repository by week'
pp week_over_week