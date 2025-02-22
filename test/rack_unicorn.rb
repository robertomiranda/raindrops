# -*- encoding: binary -*-
# frozen_string_literal: false
require "test/unit"
require "raindrops"
require "open-uri"
begin
  require "unicorn"
  require "rack"
  require "rack/lobster"
rescue LoadError => e
  warn "W: #{e} skipping test since Rack or Unicorn was not found"
end
