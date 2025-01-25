//
//  ContentView.swift
//  AIFromSratchSwiftUI
//
//  Created by Priyanka Sharma on 25/01/25.
//

import SwiftUI
import CoreLocation

// Update WeatherData model to match OpenWeatherMap API response
struct WeatherData: Identifiable, Codable {
    let id = UUID()
    let temperature: Double
    let condition: String
    let location: String
    let humidity: Int
    let windSpeed: Double
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: RootCodingKeys.self)
        
        let main = try container.decode(Main.self, forKey: .main)
        let weather = try container.decode([Weather].self, forKey: .weather)
        let wind = try container.decode(Wind.self, forKey: .wind)
        
        temperature = main.temp
        humidity = main.humidity
        condition = weather.first?.description ?? "Unknown"
        location = try container.decode(String.self, forKey: .name)
        windSpeed = wind.speed
    }
    
    // For current location manual data
    init(temperature: Double, condition: String, location: String, humidity: Int, windSpeed: Double) {
        self.temperature = temperature
        self.condition = condition
        self.location = location
        self.humidity = humidity
        self.windSpeed = windSpeed
    }
    
    private enum RootCodingKeys: String, CodingKey {
        case main
        case weather
        case wind
        case name
    }
    
    private struct Main: Codable {
        let temp: Double
        let humidity: Int
    }
    
    private struct Weather: Codable {
        let description: String
    }
    
    private struct Wind: Codable {
        let speed: Double
    }
}

// Update WeatherService with the provided API key
class WeatherService: ObservableObject {
    private let apiKey = "83e04a33cff128fd3366f73ecca5dbbc"
    @Published var weatherData: [WeatherData] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    func fetchWeatherForCities() async {
        await MainActor.run {
            self.isLoading = true
        }
        weatherData.removeAll()
        
        let cities = ["New York", "London", "Tokyo", "Sydney"]
        
        for city in cities {
            do {
                let encodedCity = city.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? city
                let urlString = "https://api.openweathermap.org/data/2.5/weather?q=\(encodedCity)&appid=\(apiKey)&units=metric"
                
                guard let url = URL(string: urlString) else { continue }
                
                let (data, _) = try await URLSession.shared.data(from: url)
                let weather = try JSONDecoder().decode(WeatherData.self, from: data)
                
                DispatchQueue.main.async {
                    self.weatherData.append(weather)
                }
            } catch {
                print("Error fetching weather for \(city): \(error)")
                self.error = error
            }
        }
        
        await MainActor.run {
            self.isLoading = false
        }
    }
    
    func searchCity(name: String) async {
        guard !name.isEmpty else { return }
        
        await MainActor.run {
            self.isLoading = true
        }
        weatherData.removeAll()
        
        do {
            let encodedCity = name.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? name
            let urlString = "https://api.openweathermap.org/data/2.5/weather?q=\(encodedCity)&appid=\(apiKey)&units=metric"
            
            guard let url = URL(string: urlString) else { return }
            
            let (data, _) = try await URLSession.shared.data(from: url)
            let weather = try JSONDecoder().decode(WeatherData.self, from: data)
            
            DispatchQueue.main.async {
                self.weatherData = [weather]
            }
        } catch {
            print("Error searching city \(name): \(error)")
            self.error = error
        }
        
        await MainActor.run {
            self.isLoading = false
        }
    }
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var location: CLLocation?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.first
        locationManager.stopUpdatingLocation()
    }
}

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var weatherService = WeatherService()
    @State private var searchText = ""
    @State private var isSearching = false
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    gradient: Gradient(colors: [.blue, .cyan]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    SearchBar(searchText: $searchText, isSearching: $isSearching)
                        .padding(.top, 10)
                        .onChange(of: searchText) { newValue in
                            if newValue.isEmpty {
                                Task {
                                    await weatherService.fetchWeatherForCities()
                                }
                            } else {
                                Task {
                                    await weatherService.searchCity(name: newValue)
                                }
                            }
                        }
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            if searchText.isEmpty, let _ = locationManager.location {
                                WeatherCard(weather: WeatherData(
                                    temperature: 25,
                                    condition: "Sunny",
                                    location: "Current Location",
                                    humidity: 68,
                                    windSpeed: 14
                                ))
                                .padding(.top)
                            }
                            
                            ForEach(weatherService.weatherData) { weather in
                                WeatherCard(weather: weather)
                            }
                            
                            if weatherService.weatherData.isEmpty && !searchText.isEmpty {
                                Text("No cities found")
                                    .foregroundColor(.white)
                                    .padding()
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Weather")
            .task {
                await weatherService.fetchWeatherForCities()
            }
        }
    }
}

struct SearchBar: View {
    @Binding var searchText: String
    @Binding var isSearching: Bool
    
    var body: some View {
        HStack {
            TextField("Search city...", text: $searchText)
                .padding(8)
                .padding(.horizontal, 25)
                .background(Color.white)
                .cornerRadius(8)
                .overlay(
                    HStack {
                        // Search icon
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                            .padding(.leading, 8)
                        
                        // Clear button
                        if !searchText.isEmpty {
                            Button(action: {
                                searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .padding(.trailing, 8)
                            }
                        }
                    }
                )
        }
        .padding(.horizontal)
        .animation(.default, value: searchText)
    }
}

struct WeatherCard: View {
    let weather: WeatherData
    
    var body: some View {
        VStack(spacing: 15) {
            Text(weather.location)
                .font(.title2)
                .bold()
                .foregroundColor(.white)
            
            HStack {
                VStack(alignment: .leading) {
                    Image(systemName: "sun.max.fill")
                        .renderingMode(.original)
                        .font(.system(size: 40))
                    
                    Text("\(Int(round(weather.temperature)))°")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 10) {
                    WeatherDetailItem(icon: "humidity", value: "\(weather.humidity)%")
                    WeatherDetailItem(icon: "wind", value: "\(Int(round(weather.windSpeed))) km/h")
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(15)
    }
}

struct WeatherDetailItem: View {
    let icon: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white)
            Text(value)
                .foregroundColor(.white)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
