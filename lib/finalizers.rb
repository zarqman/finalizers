module Finalizers
end

%w(engine version).each do |f|
  require "finalizers/#{f}"
end
