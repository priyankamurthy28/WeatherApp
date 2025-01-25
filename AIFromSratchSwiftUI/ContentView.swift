//
//  ContentView.swift
//  AIFromSratchSwiftUI
//
//  Created by Priyanka Sharma on 25/01/25.
//

import SwiftUI
import CoreLocation

struct WeatherData: Identifiable {
    let id = UUID()
    let temperature: Int
    let condition: String
    let location: String
    let humidity: Int
    let windSpeed: Int
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
    @State private var searchText = ""
    @State private var isSearching = false
    
    // Sample weather data for four cities
    let cities = [
        WeatherData(temperature: 23, condition: "Sunny", location: "New York", humidity: 65, windSpeed: 12),
        WeatherData(temperature: 18, condition: "Cloudy", location: "London", humidity: 75, windSpeed: 15),
        WeatherData(temperature: 28, condition: "Clear", location: "Tokyo", humidity: 60, windSpeed: 8),
        WeatherData(temperature: 32, condition: "Partly Cloudy", location: "Sydney", humidity: 70, windSpeed: 10)
    ]
    
    // Filtered cities based on search
    var filteredCities: [WeatherData] {
        if searchText.isEmpty {
            return cities
        } else {
            return cities.filter { $0.location.lowercased().contains(searchText.lowercased()) }
        }
    }
    
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
                    // Search Bar at top
                    SearchBar(searchText: $searchText, isSearching: $isSearching)
                        .padding(.top, 10)
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            // Show current location only when not searching
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
                            
                            // Filtered City Weather Cards
                            ForEach(filteredCities) { city in
                                WeatherCard(weather: city)
                            }
                            
                            // Show message if no cities found
                            if filteredCities.isEmpty && !searchText.isEmpty {
                                Text("No cities found")
                                    .foregroundColor(.white)
                                    .padding()
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(Text("Weather").bold())
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
                    
                    Text("\(weather.temperature)°")
                        .font(.system(size: 50, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 10) {
                    WeatherDetailItem(icon: "humidity", value: "\(weather.humidity)%")
                    WeatherDetailItem(icon: "wind", value: "\(weather.windSpeed) km/h")
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
