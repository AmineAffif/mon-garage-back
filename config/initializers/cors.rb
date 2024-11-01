Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins Rails.env.production? ? 'https://mon-garage-d73hunanv-amine-affifs-projects.vercel.app' : 'http://localhost:3001'

    resource '/api/*',
             headers: :any,
             methods: [:get, :post, :put, :patch, :delete, :options, :head],
             credentials: true
  end
end
