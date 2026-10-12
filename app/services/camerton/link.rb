module Camerton
  # A supported music link, normalized: url is the canonical form, without
  # tracking parameters such as "si".
  Link = Data.define(:platform, :kind, :external_id, :url)
end
