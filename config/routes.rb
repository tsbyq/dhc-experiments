Rails.application.routes.draw do
  # get 'district_systems/index'

  get 'welcome/index'

  get "district_systems", to: "district_systems#index"

  # TODO: Two post requests on the same view?
  post "district_systems", to: "district_systems#dispatcher"

  # get "district_systems", to: "district_systems#simulate"

  # post "district_systems", to: "district_systems#simulate"

  root to: 'welcome#index'
end
