#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/hra_monitor"

options = { scrapes: [], nodes: [], env: "production" }

parser = OptionParser.new do |opts|
  opts.banner = <<~BANNER
    Usage: bin/add-app --name APP [options]

    Registers an application in apps.yml, regenerates Prometheus file_sd,
    and prints the Rails/Kamal checklist.

    Example:
      bin/add-app --name chatgrid \\
        --health-url https://chatgrid.ru/up \\
        --scrape web=https://chatgrid.ru/metrics \\
        --node chatgrid.ru
  BANNER

  opts.on("--name NAME", "Application name (required)") { |value| options[:name] = value }
  opts.on("--env ENV", "Environment label (default: production)") { |value| options[:env] = value }
  opts.on("--health-url URL", "Public healthcheck URL for blackbox probes") { |value| options[:health_url] = value }
  opts.on("--scrape ROLE=URL", "Scrape target, repeatable (web=https://app/metrics)") do |value|
    role, url = value.split("=", 2)
    abort "Invalid --scrape #{value.inspect}, expected ROLE=URL" if url.nil? || url.empty?
    options[:scrapes] << { "job" => role, "url" => url, "labels" => { "role" => role } }
  end
  opts.on("--node HOST", "Host running node-exporter :9100, repeatable") { |value| options[:nodes] << value }
  opts.on("-h", "--help", "Show this help") do
    puts opts
    exit
  end
end

parser.parse!
abort(parser.to_s) if options[:name].to_s.empty?

result = HraMonitor.add_app!(options)
puts "Registered #{result[:name]}"
puts YAML.dump(result[:config]).sub(/\A---\n/, "")
puts
puts "file_sd: rails=#{result[:stats][:rails]} nodes=#{result[:stats][:nodes]} probes=#{result[:stats][:probes]}"
puts
puts result[:checklist]
puts
puts "Next: copy templates/app into the Rails app, open firewall ports, then run bin/apply."
