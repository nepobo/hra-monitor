#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/hra_monitor"

stats = HraMonitor.render!
puts "Rendered Prometheus file_sd from apps.yml"
puts "  apps=#{stats[:apps]} rails_targets=#{stats[:rails]} nodes=#{stats[:nodes]} probes=#{stats[:probes]}"
puts "  #{File.join(HraMonitor::FILE_SD_DIR, "rails.yml")}"
puts "  #{File.join(HraMonitor::FILE_SD_DIR, "nodes.yml")}"
puts "  #{File.join(HraMonitor::FILE_SD_DIR, "blackbox.yml")}"
