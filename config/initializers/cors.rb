Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins 'http://localhost:3001', Rails.env.production? ? 'https://mon-garage-d73hunanv-amine-affifs-projects.vercel.app' : '*'

    resource '/api/*',
             headers: :any,
             methods: [:get, :post, :put, :patch, :delete, :options, :head],
             credentials: true
  end
end
