namespace :news do
  desc "Fetch AI news from RSS feeds and save filtered posts (requires ANTHROPIC_API_KEY)"
  task fetch: :environment do
    count = NewsAggregator.call
    puts "#{count} new post(s) saved."
  end
end
