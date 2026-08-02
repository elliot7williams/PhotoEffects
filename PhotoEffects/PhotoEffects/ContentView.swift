//
//  ContentView.swift
//  PhotoFilters
//
//  Created by Elliot Williams on 2025-06-03.
//

import SwiftUI
import AVFoundation
import CoreImage
import Photos

struct ContentView: View {
    @StateObject private var cameraManager = CameraManager()
    @State private var showFilters = false
    @State private var showCapturedImage = false
    @State private var ringLightBrightness: CGFloat = 50
    @State private var showMessages = false
    @GestureState private var dragOffset: CGFloat = 0
    @State private var activeDrag: Bool = false
    @State private var cubeRotation: Double = 0
    @State private var isAppActive = false
    
    var body: some View {
        ZStack {
            // Camera Interface (front face)
            ZStack {
                // Camera Preview
                CameraPreview(session: cameraManager.session, cameraManager: cameraManager)
                    .edgesIgnoringSafeArea(.all)
                    .overlay(
                        Group {
                            if cameraManager.ringLightActive {
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        .clear,
                                        .clear,
                                        Color.white.opacity(ringLightBrightness * 0.005),
                                        Color.white.opacity(ringLightBrightness * 0.008)
                                    ]),
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: UIScreen.main.bounds.width
                                )
                                .blendMode(.lighten)
                                .allowsHitTesting(false)
                            }
                        }
                    )
                
                // Flash Effect
                if cameraManager.isFlashing {
                    Color.white
                        .edgesIgnoringSafeArea(.all)
                        .animation(.easeOut(duration: 0.3), value: cameraManager.isFlashing)
                }
                
                // Captured Image Overlay
                if showCapturedImage, let image = cameraManager.capturedImage {
                    ZStack {
                        Color.black.edgesIgnoringSafeArea(.all)
                        
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                        
                        VStack {
                            Spacer()
                            HStack(spacing: 40) {
                                Button(action: {
                                    cameraManager.savePhoto()
                                    showCapturedImage = false
                                }) {
                                    CircleButton(icon: "arrow.down.circle.fill")
                                }
                                
                                Button(action: {
                                    showCapturedImage = false
                                }) {
                                    CircleButton(icon: "xmark.circle.fill")
                                }
                            }
                            .padding(.bottom, 40)
                        }
                    }
                    .transition(.opacity)
                    .zIndex(2)
                }
                
                // Controls
                VStack {
                    if showFilters {
                        FilterListView(selectedFilter: $cameraManager.currentFilter)
                            .frame(maxHeight: 200)
                            .padding(.top, 20)
                            .transition(.move(edge: .top))
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 20) {
                        if cameraManager.ringLightActive {
                            Slider(value: $ringLightBrightness, in: 0...100)
                                .padding(.horizontal, 40)
                                .onChange(of: ringLightBrightness) { _ in
                                    cameraManager.updateRingLight(brightness: ringLightBrightness)
                                }
                        }
                        
                        HStack(spacing: 40) {
                            Button(action: {
                                cameraManager.switchCamera()
                            }) {
                                CircleButton(icon: "arrow.triangle.2.circlepath")
                            }
                            
                            Button(action: {
                                cameraManager.capturePhoto()
                                withAnimation { showCapturedImage = true }
                            }) {
                                Circle()
                                    .stroke(Color.white, lineWidth: 4)
                                    .frame(width: 70, height: 70)
                            }
                            
                            Button(action: {
                                withAnimation { showFilters.toggle() }
                            }) {
                                CircleButton(icon: "camera.filters")
                            }
                            
                            Button(action: {
                                cameraManager.toggleRingLight()
                            }) {
                                CircleButton(icon: "lightbulb.fill")
                                    .opacity(cameraManager.ringLightActive ? 1 : 0.5)
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .rotation3DEffect(
                .degrees(showMessages ? -90 : 0),
                axis: (x: 1, y: 0, z: 0),
                anchor: .top,
                perspective: 0.1
            )
            .zIndex(showMessages ? 0 : 1)
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            isAppActive = true
            // Start camera immediately when app appears
            DispatchQueue.main.async {
                cameraManager.checkCameraPermission()
            }
        }
        .onDisappear {
            isAppActive = false
            cameraManager.session.stopRunning()
        }
        .onChange(of: showMessages) { newValue in
            if newValue {
                cameraManager.session.stopRunning()
            } else if isAppActive {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    cameraManager.setupCaptureSession()
                }
            }
        }
        .onTapGesture {
            hideKeyboard()
        }
    }
    
    private func hapticFeedback(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
}

// MARK: - 3D Rotation Extension
extension View {
    func customRotation3DEffect(
        _ angle: Angle,
        axis: (x: CGFloat, y: CGFloat, z: CGFloat),
        anchor: UnitPoint,
        anchorZ: CGFloat,
        perspective: CGFloat
    ) -> some View {
        return self
            .transformEffect(
                CGAffineTransform(translationX: anchor.x * UIScreen.main.bounds.width, y: anchor.y * UIScreen.main.bounds.height)
            )
            .transform3DEffect(
                Transform3D(
                    m11: cos(angle.radians) + axis.x * axis.x * (1 - cos(angle.radians)),
                    m12: axis.x * axis.y * (1 - cos(angle.radians)) - axis.z * sin(angle.radians),
                    m13: axis.x * axis.z * (1 - cos(angle.radians)) + axis.y * sin(angle.radians),
                    m14: 0,
                    
                    m21: axis.y * axis.x * (1 - cos(angle.radians)) + axis.z * sin(angle.radians),
                    m22: cos(angle.radians) + axis.y * axis.y * (1 - cos(angle.radians)),
                    m23: axis.y * axis.z * (1 - cos(angle.radians)) - axis.x * sin(angle.radians),
                    m24: 0,
                    
                    m31: axis.z * axis.x * (1 - cos(angle.radians)) - axis.y * sin(angle.radians),
                    m32: axis.z * axis.y * (1 - cos(angle.radians)) + axis.x * sin(angle.radians),
                    m33: cos(angle.radians) + axis.z * axis.z * (1 - cos(angle.radians)),
                    m34: perspective,
                    
                    m41: 0,
                    m42: 0,
                    m43: 0,
                    m44: 1
                )
                .translatedBy(x: -anchor.x * UIScreen.main.bounds.width, y: -anchor.y * UIScreen.main.bounds.height, z: anchorZ)
            )
    }
}

struct Transform3D {
    var m11: CGFloat, m12: CGFloat, m13: CGFloat, m14: CGFloat
    var m21: CGFloat, m22: CGFloat, m23: CGFloat, m24: CGFloat
    var m31: CGFloat, m32: CGFloat, m33: CGFloat, m34: CGFloat
    var m41: CGFloat, m42: CGFloat, m43: CGFloat, m44: CGFloat
    
    func translatedBy(x: CGFloat, y: CGFloat, z: CGFloat) -> Transform3D {
        var transform = self
        transform.m41 += x
        transform.m42 += y
        transform.m43 += z
        return transform
    }
}

extension View {
    func transform3DEffect(_ transform: Transform3D) -> some View {
        return self
            .modifier(Transform3DModifier(transform: transform))
    }
}

struct Transform3DModifier: ViewModifier {
    var transform: Transform3D
    
    func body(content: Content) -> some View {
        content
            .projectionEffect(
                ProjectionTransform(
                    CGAffineTransform(
                        a: transform.m11, b: transform.m12,
                        c: transform.m21, d: transform.m22,
                        tx: transform.m41, ty: transform.m42
                    )
                )
            )
    }
}

struct CircleButton: View {
    let icon: String
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 50, height: 50)
            
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
        }
    }
}

func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}

struct FilterListView: View {
    @Binding var selectedFilter: String
    @State private var searchText = ""
    let filters = [
        // Basic Effects
        "Normal", "B&W", "Sepia", "Invert", "Blur", "Bright", "High Contrast", "Color Shift", "Vibrant", "Vintage",
        "Cyberpunk", "Dreamy", "Film Noir", "Matrix", "Arctic", "Sunset", "Thermal", "Purple Haze", "Neon", "Underwater",
        
        // Retro & Aesthetic
        "Retro Wave", "Synthwave", "Vaporwave", "Outrun", "Midnight", "Golden Hour", "Anime", "Pixel", "Chrome",
        "Polaroid", "Vintage Film", "Cross Process", "Lomography", "Film Grain", "Light Leak", "Instant Camera",
        
        // Artistic Styles
        "Oil Painting", "Watercolor", "Pastel", "Duotone", "Blueprint", "Infrared", "Pointillism", "Abstract",
        "Impressionist", "Pop Art", "Comic Book", "Sketch", "Charcoal", "Ink Wash", "Brushstroke",
        
        // Nature & Environment
        "Desert", "Forest", "Arctic Aurora", "Northern Lights", "Volcano", "Deep Sea", "Moonlight", "Stardust",
        "Cosmic", "Mars", "Space Dust", "Ocean Breeze", "Mountain Mist", "Prairie", "Jungle", "Sahara",
        
        // Mood & Atmosphere
        "Haunted", "Mystic", "Enchanted", "Dreamy Soft", "Noir Shadow", "Ethereal", "Melancholic", "Euphoric",
        "Serene", "Dramatic", "Moody", "Contemplative", "Energetic", "Peaceful", "Intense", "Calm",
        
        // Sci-Fi & Fantasy
        "Hologram", "Plasma", "Toxic", "Radioactive", "Electric", "Quantum", "Dimension X", "Time Warp",
        "Alien", "Futuristic", "Cybernetic", "Digital", "Glitch Core", "Data Stream", "Neural", "Virtual",
        
        // Color Themes
        "Candy", "Cotton Candy", "Bubblegum", "Rainbow", "Acid", "Lava", "Frostbite", "Crystal",
        "Gold Rush", "Silver Lining", "Copper", "Bronze", "Emerald", "Ruby", "Sapphire", "Pearl",
        
        // Weather & Seasons
        "Spring Bloom", "Summer Heat", "Autumn Leaves", "Winter Snow", "Stormy", "Foggy", "Sunny", "Cloudy",
        "Rain", "Thunder", "Lightning", "Hail", "Mist", "Frost", "Dew", "Haze",
        
        // Time Periods
        "Ancient", "Medieval", "Renaissance", "Victorian", "Art Deco", "50s Retro", "60s Psychedelic", "70s Funk",
        "80s Neon", "90s Grunge", "Y2K", "Modern", "Future", "Stone Age", "Industrial", "Digital Age",
        
        // Food & Drinks
        "Chocolate", "Vanilla", "Strawberry", "Mint", "Lemon", "Orange", "Coffee", "Tea",
        "Wine", "Champagne", "Honey", "Caramel", "Lavender", "Rose", "Cinnamon", "Pepper",
        
        // Textures & Materials
        "Velvet", "Silk", "Satin", "Denim", "Leather", "Wood", "Metal", "Glass",
        "Marble", "Granite", "Sand", "Clay", "Fabric", "Paper", "Plastic", "Ceramic",
        
        // Lighting Effects
        "Soft Light", "Hard Light", "Rim Light", "Back Light", "Side Light", "Top Light", "Under Light", "Ring Light",
        "Spotlight", "Flood Light", "Candle Light", "Neon Light", "LED", "Fluorescent", "Incandescent", "Natural Light",
        
        // Abstract Concepts
        "Love", "Joy", "Sadness", "Anger", "Fear", "Surprise", "Disgust", "Trust",
        "Hope", "Despair", "Freedom", "Chaos", "Order", "Balance", "Harmony", "Discord",
        
        // Fantasy & Magic
        "Dragon Fire", "Fairy Dust", "Wizard", "Mermaid", "Phoenix", "Unicorn", "Starfall", "Magic Portal",
        "Crystal Ball", "Enchanted Forest", "Potion", "Spell", "Rune", "Mystic Fog", "Spirit", "Aura",
        
        // Gemstones & Crystals
        "Amethyst", "Topaz", "Opal", "Onyx", "Jade", "Turquoise", "Citrine", "Garnet",
        "Aquamarine", "Peridot", "Moonstone", "Sunstone", "Labradorite", "Malachite", "Quartz", "Obsidian",
        
        // Space & Cosmos
        "Galaxy", "Nebula", "Black Hole", "Supernova", "Asteroid", "Comet", "Solar Flare", "Pulsar",
        "Wormhole", "Stargate", "Orbit", "Eclipse", "Meteor", "Satellite", "Planetary", "Cosmic Dust",
        
        // Elements & Forces
        "Lightning", "Tornado", "Earthquake", "Tsunami", "Avalanche", "Blizzard", "Hurricane", "Wildfire",
        "Magnetic", "Gravity", "Nuclear", "Solar", "Lunar", "Tidal", "Geothermal", "Wind",
        
        // Music & Sound
        "Bass Drop", "Reverb", "Echo", "Distortion", "Chorus", "Harmony", "Melody", "Rhythm",
        "Jazz", "Blues", "Rock", "Electronic", "Classical", "Hip Hop", "Reggae", "Country",
        
        // Technology & Digital
        "Binary", "Circuit", "Laser", "Holographic", "Pixel Art", "Wireframe", "Code", "Data",
        "Scan Lines", "Glitch TV", "VHS", "8-Bit", "16-Bit", "Retro Computer", "Matrix Code", "Digital Rain",
        
        // Emotions & Feelings
        "Euphoria", "Nostalgia", "Tranquil", "Energized", "Mysterious", "Playful", "Romantic", "Adventurous",
        "Rebellious", "Confident", "Vulnerable", "Powerful", "Gentle", "Wild", "Elegant", "Quirky",
        
        // Art Movements
        "Impressionism", "Cubism", "Surrealism", "Pop Art", "Abstract", "Minimalism", "Bauhaus", "Art Deco",
        "Expressionism", "Fauvism", "Dadaism", "Futurism", "Constructivism", "Suprematism", "Neo-Classical", "Romantic",
        
        // Cultural & Regional
        "Japanese", "Chinese", "Indian", "African", "Native American", "Celtic", "Nordic", "Mediterranean",
        "Tropical", "Arctic", "Desert Nomad", "Mountain", "Coastal", "Urban", "Rural", "Bohemian",
        
        // Fabrics & Patterns
        "Plaid", "Stripes", "Polka Dots", "Chevron", "Paisley", "Floral", "Geometric", "Tribal",
        "Damask", "Houndstooth", "Argyle", "Tartan", "Ikat", "Batik", "Tie Dye", "Ombre",
        
        // Architectural Styles
        "Gothic", "Modern", "Classical", "Industrial", "Minimalist", "Baroque", "Victorian", "Art Nouveau",
        "Brutalist", "Bauhaus Style", "Mediterranean", "Colonial", "Prairie", "Ranch", "Tudor", "Contemporary",
        
        // Mythical Creatures
        "Dragon", "Griffin", "Pegasus", "Kraken", "Sphinx", "Chimera", "Hydra", "Banshee",
        "Valkyrie", "Centaur", "Minotaur", "Siren", "Gargoyle", "Wendigo", "Kelpie", "Djinn",
        
        // Urban & Street
        "Graffiti", "Neon Signs", "Street Art", "Underground", "Skyscraper", "Subway", "Traffic", "City Lights",
        "Concrete", "Steel", "Asphalt", "Brick", "Rust", "Decay", "Renovation", "Construction",
        
        // Ocean & Water
        "Tsunami Wave", "Coral Reef", "Deep Ocean", "Tide Pool", "Whirlpool", "Waterfall", "River", "Lake",
        "Reflection", "Ripples", "Splash", "Foam", "Mist", "Steam", "Ice", "Droplets",
        
        // Fire & Heat
        "Campfire", "Candle Flame", "Forge", "Ember", "Smoke", "Ash", "Spark", "Inferno",
        "Molten", "Scorched", "Blazing", "Smoldering", "Flicker", "Glow", "Heat Wave", "Solar Burn",
        
        // Ice & Cold
        "Icicle", "Snowflake", "Glacier", "Permafrost", "Ice Crystal", "Frozen", "Chill", "Arctic Wind",
        "Frost Pattern", "Ice Cave", "Blizzard", "Hail Storm", "Ice Age", "Polar", "Tundra", "Iceberg",
        
        // Plants & Flowers
        "Rose Garden", "Sunflower", "Cherry Blossom", "Autumn Leaves", "Pine Forest", "Bamboo", "Lotus", "Orchid",
        "Cactus", "Moss", "Fern", "Vine", "Tulip", "Lavender Field", "Poppy", "Dandelion",
        
        // Animals & Wildlife
        "Tiger Stripes", "Leopard Spots", "Zebra", "Peacock", "Butterfly", "Eagle", "Wolf", "Dolphin",
        "Elephant", "Lion", "Panda", "Giraffe", "Penguin", "Owl", "Fox", "Deer",
        
        // Extreme Effects
        "Nuclear Blast", "Time Distortion", "Reality Glitch", "Dimension Shift", "Quantum Flux", "Energy Field",
        "Force Field", "Magnetic Storm", "Solar Storm", "Cosmic Ray", "Black Light", "X-Ray",
        
        // Vintage Technology
        "Film Strip", "Polaroid Border", "TV Static", "Radio Waves", "Telegraph", "Morse Code", "Vinyl", "Cassette",
        "CD Reflection", "Floppy Disk", "CRT Monitor", "Dot Matrix", "Green Screen", "Amber Monitor", "Nixie Tube", "Vacuum Tube",
        
        // Beverages & Liquids
        "Espresso", "Green Tea", "Red Wine", "Whiskey", "Cocktail", "Smoothie", "Milk", "Oil",
        "Honey Drip", "Syrup", "Paint", "Ink", "Mercury", "Lava Flow", "Watercolor Wash", "Blood",
        
        // Professional Photography
        "Studio Portrait", "Fashion", "Macro", "Telephoto", "Wide Angle", "Fish Eye", "Tilt Shift", "Bokeh",
        "Double Exposure", "Long Exposure", "High Speed", "Time Lapse", "Stop Motion", "Light Painting", "HDR", "Panoramic"
    ]
    
    // Computed property for filtered filters
    var filteredFilters: [String] {
        if searchText.isEmpty {
            return filters
        } else {
            return filters.filter { $0.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("Search filters", text: $searchText)
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(10)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal)
        
            // Filter list
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(filteredFilters, id: \.self) { filter in
                        Button(action: {
                            selectedFilter = filter
                        }) {
                            Text(filter)
                                .font(.caption)
                                .padding(8)
                                .background(selectedFilter == filter ? Color.blue : Color.white.opacity(0.2))
                                .foregroundColor(.white)
                                .cornerRadius(15)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: 200)
        }
        .padding(.top, 20)
        .background(Color.black.opacity(0.7))
        .transition(.move(edge: .top))
    }
}

// MARK: - CameraManager with Permission Handling
class CameraManager: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var session = AVCaptureSession()
    @Published var capturedImage: UIImage?
    @Published var isFlashing = false
    @Published var ringLightActive = false
    @Published var currentFilter = "Normal" {
        didSet {
            updatePreviewFilter()
        }
    }
    @Published var isSessionSetup = false
    @Published var filteredPreviewImage: UIImage?
    
    private var captureOutput = AVCapturePhotoOutput()
    private var videoDataOutput = AVCaptureVideoDataOutput()
    private var captureDevice: AVCaptureDevice?
    private var position: AVCaptureDevice.Position = .back
    private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    private let videoDataOutputQueue = DispatchQueue(label: "video.data.output.queue")
    private let ciContext = CIContext()
    
    override init() {
        super.init()
        // Initialize camera session immediately
        configureSession()
    }
    
    private func configureSession() {
        session.sessionPreset = .photo
        captureOutput.maxPhotoQualityPrioritization = .quality
    }
    
    func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async {
                self.setupCaptureSession()
            }
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    DispatchQueue.main.async {
                        self.setupCaptureSession()
                    }
                } else {
                    print("Camera access denied by user")
                }
            }
        case .denied, .restricted:
            print("Camera access denied or restricted")
        @unknown default:
            print("Unknown camera authorization status")
        }
    }
    
    func setupCaptureSession() {
        sessionQueue.async {
            guard !self.session.isRunning else { return }
            
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: self.position) else {
                print("Camera device not found")
                return
            }
            self.captureDevice = device
            
            do {
                self.session.beginConfiguration()
                
                // Remove existing inputs
                self.session.inputs.forEach { self.session.removeInput($0) }
                
                let input = try AVCaptureDeviceInput(device: device)
                if self.session.canAddInput(input) {
                    self.session.addInput(input)
                }
                
                // Remove existing outputs
                self.session.outputs.forEach { self.session.removeOutput($0) }
                
                if self.session.canAddOutput(self.captureOutput) {
                    self.session.addOutput(self.captureOutput)
                }
                
                // Setup video data output for real-time filtering
                self.videoDataOutput.setSampleBufferDelegate(self, queue: self.videoDataOutputQueue)
                self.videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                if self.session.canAddOutput(self.videoDataOutput) {
                    self.session.addOutput(self.videoDataOutput)
                }
                
                self.session.sessionPreset = .photo
                self.session.commitConfiguration()
                
                // Start running session
                self.session.startRunning()
                
                DispatchQueue.main.async {
                    self.isSessionSetup = true
                }
            } catch {
                print("Camera setup error: \(error.localizedDescription)")
            }
        }
    }
    
    func switchCamera() {
        session.stopRunning()
        position = (position == .back) ? .front : .back
        setupCaptureSession()
    }
    
    func capturePhoto() {
        isFlashing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isFlashing = false
        }
        
        let settings = AVCapturePhotoSettings()
        captureOutput.capturePhoto(with: settings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), var image = UIImage(data: data) else {
            print("Failed to get image data")
            return
        }
        
        // Apply selected filter
        image = applyFilter(to: image, filterName: currentFilter)
        
        // Apply ring light effect if active
        if ringLightActive {
            image = applyRingLight(to: image)
        }
        
        capturedImage = image
    }
    
    func toggleRingLight() {
        ringLightActive.toggle()
    }
    
    func updateRingLight(brightness: CGFloat) {
        // Brightness is applied in capture process
    }
    
func savePhoto() {
        guard let image = capturedImage else {
            print("No image to save")
            return
        }
        
        if #available(iOS 14, *) {
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                switch status {
                case .authorized, .limited:
                    self.performSave(image: image)
                case .denied, .restricted:
                    print("Photo library access was denied or restricted.")
                case .notDetermined:
                    print("Photo library access not determined.")
                @unknown default:
                    print("Unknown photo library authorization status.")
                }
            }
        } else {
            PHPhotoLibrary.requestAuthorization { status in
                switch status {
                case .authorized:
                    self.performSave(image: image)
                case .denied, .restricted:
                    print("Photo library access was denied or restricted.")
                case .notDetermined:
                    print("Photo library access not determined.")
                @unknown default:
                    print("Unknown photo library authorization status.")
                }
            }
        }
    }
    
    private func performSave(image: UIImage) {
        PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        }, completionHandler: { success, error in
            DispatchQueue.main.async {
                if success {
                    print("Photo saved successfully!")
                } else if let error = error {
                    print("Error saving photo: \(error.localizedDescription)")
                } else {
                    print("Unknown error occurred while saving photo")
                }
            }
        })
    }
    
    private func applyFilter(to image: UIImage, filterName: String) -> UIImage {
        guard let ciImage = CIImage(image: image) else { return image }
        var outputImage = ciImage
        
        switch filterName {
        case "B&W":
            outputImage = outputImage.applyingFilter("CIPhotoEffectMono")
        case "Sepia":
            outputImage = outputImage.applyingFilter("CISepiaTone", parameters: ["inputIntensity": 1.0])
        case "Invert":
            outputImage = outputImage.applyingFilter("CIColorInvert")
        case "Blur":
            outputImage = outputImage.applyingFilter("CIGaussianBlur", parameters: ["inputRadius": 5.0])
        case "Bright":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputBrightness": 0.3])
        case "High Contrast":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputContrast": 1.5])
        case "Color Shift":
            outputImage = outputImage.applyingFilter("CIHueAdjust", parameters: ["inputAngle": 3.0])
        case "Vibrant":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 1.8])
        case "Vintage":
            outputImage = outputImage.applyingFilter("CIPhotoEffectInstant")
        case "Cyberpunk":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 2.0, "inputContrast": 1.2])
            outputImage = outputImage.applyingFilter("CIHueAdjust", parameters: ["inputAngle": 2.0])
        case "Dreamy":
            outputImage = outputImage.applyingFilter("CIBloom", parameters: ["inputRadius": 5.0, "inputIntensity": 1.0])
        case "Film Noir":
            outputImage = outputImage.applyingFilter("CIPhotoEffectNoir")
        case "Matrix":
            outputImage = outputImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0, y: 1, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 1, z: 0, w: 0)
            ])
        // Add more filters as needed...
        default:
            break
        }
        
        guard let cgImage = CIContext().createCGImage(outputImage, from: outputImage.extent) else { return image }
        return UIImage(cgImage: cgImage)
    }
    
    private func applyRingLight(to image: UIImage) -> UIImage {
        let size = image.size
        UIGraphicsBeginImageContext(size)
        
        image.draw(at: .zero)
        
        let center = CGPoint(x: size.width/2, y: size.height/2)
        let radius = min(size.width, size.height) / 2
        
        let context = UIGraphicsGetCurrentContext()!
        let locations: [CGFloat] = [0.8, 0.9, 1.0]
        let colors = [
            UIColor.clear.cgColor,
            UIColor.white.withAlphaComponent(0.2).cgColor,
            UIColor.white.withAlphaComponent(0.4).cgColor
        ]
        
        let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors as CFArray,
            locations: locations
        )!
        
        context.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: radius,
            options: .drawsAfterEndLocation
        )
        
        let result = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        return result
    }
    
    // MARK: - Real-time Filter Application
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard currentFilter != "Normal" else {
            DispatchQueue.main.async {
                self.filteredPreviewImage = nil
            }
            return
        }
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let filteredImage = applyFilterToCIImage(ciImage, filterName: currentFilter)
        
        guard let cgImage = ciContext.createCGImage(filteredImage, from: filteredImage.extent) else { return }
        let uiImage = UIImage(cgImage: cgImage)
        
        DispatchQueue.main.async {
            self.filteredPreviewImage = uiImage
        }
    }
    
    private func updatePreviewFilter() {
        // This will trigger the video output delegate to update the preview
        if currentFilter == "Normal" {
            DispatchQueue.main.async {
                self.filteredPreviewImage = nil
            }
        }
    }
    
    private func applyFilterToCIImage(_ image: CIImage, filterName: String) -> CIImage {
        var outputImage = image
        
        switch filterName {
        // Basic Effects
        case "B&W":
            outputImage = outputImage.applyingFilter("CIPhotoEffectMono")
        case "Sepia":
            outputImage = outputImage.applyingFilter("CISepiaTone", parameters: ["inputIntensity": 1.0])
        case "Invert":
            outputImage = outputImage.applyingFilter("CIColorInvert")
        case "Blur":
            outputImage = outputImage.applyingFilter("CIGaussianBlur", parameters: ["inputRadius": 5.0])
        case "Bright":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputBrightness": 0.3])
        case "High Contrast":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputContrast": 1.5])
        case "Color Shift":
            outputImage = outputImage.applyingFilter("CIHueAdjust", parameters: ["inputAngle": 3.14])
        case "Vibrant":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 1.8])
        case "Vintage":
            outputImage = outputImage.applyingFilter("CIPhotoEffectInstant")
        case "Cyberpunk":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 2.0, "inputContrast": 1.2])
            outputImage = outputImage.applyingFilter("CIHueAdjust", parameters: ["inputAngle": 2.0])
        case "Dreamy":
            outputImage = outputImage.applyingFilter("CIBloom", parameters: ["inputRadius": 5.0, "inputIntensity": 1.0])
        case "Film Noir":
            outputImage = outputImage.applyingFilter("CIPhotoEffectNoir")
        case "Matrix":
            outputImage = outputImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0, y: 1, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 1, z: 0, w: 0)
            ])
        case "Arctic":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 0.8, "inputBrightness": 0.2])
            outputImage = outputImage.applyingFilter("CITemperatureAndTint", parameters: ["inputNeutral": CIVector(x: 6500, y: 50), "inputTargetNeutral": CIVector(x: 8000, y: 0)])
        case "Sunset":
            outputImage = outputImage.applyingFilter("CITemperatureAndTint", parameters: ["inputNeutral": CIVector(x: 6500, y: 0), "inputTargetNeutral": CIVector(x: 3000, y: 50)])
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 1.3, "inputContrast": 1.1])
        case "Thermal":
            outputImage = outputImage.applyingFilter("CIFalseColor", parameters: [
                "inputColor0": CIColor.red,
                "inputColor1": CIColor.yellow
            ])
        case "Purple Haze":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 1.5])
            outputImage = outputImage.applyingFilter("CIHueAdjust", parameters: ["inputAngle": 1.57])
        case "Neon":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 2.5, "inputContrast": 1.8])
            outputImage = outputImage.applyingFilter("CIBloom", parameters: ["inputRadius": 3.0, "inputIntensity": 0.8])
        case "Underwater":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 1.2])
            outputImage = outputImage.applyingFilter("CITemperatureAndTint", parameters: ["inputNeutral": CIVector(x: 6500, y: 0), "inputTargetNeutral": CIVector(x: 8000, y: -100)])
            
        // New Creative Effects
        case "Retro Wave":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 1.8, "inputContrast": 1.3])
            outputImage = outputImage.applyingFilter("CIHueAdjust", parameters: ["inputAngle": 5.5])
        case "Midnight":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputBrightness": -0.3, "inputContrast": 1.4, "inputSaturation": 1.2])
        case "Golden Hour":
            outputImage = outputImage.applyingFilter("CITemperatureAndTint", parameters: ["inputNeutral": CIVector(x: 6500, y: 0), "inputTargetNeutral": CIVector(x: 2800, y: 30)])
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 1.4, "inputContrast": 1.1])
        case "Acid":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 3.0, "inputContrast": 1.5])
            outputImage = outputImage.applyingFilter("CIHueAdjust", parameters: ["inputAngle": 2.5])
        case "Rainbow":
            outputImage = outputImage.applyingFilter("CIHueAdjust", parameters: ["inputAngle": 1.0])
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 2.0])
        case "Cosmic":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 2.2, "inputContrast": 1.6])
            outputImage = outputImage.applyingFilter("CIBloom", parameters: ["inputRadius": 4.0, "inputIntensity": 1.2])
        case "Glitch":
            outputImage = outputImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1.2, y: 0, z: 0.1, w: 0),
                "inputGVector": CIVector(x: 0.1, y: 1, z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0.1, z: 1.2, w: 0)
            ])
        case "Pastel":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 0.7, "inputBrightness": 0.2, "inputContrast": 0.8])
        case "Desert":
            outputImage = outputImage.applyingFilter("CITemperatureAndTint", parameters: ["inputNeutral": CIVector(x: 6500, y: 0), "inputTargetNeutral": CIVector(x: 3200, y: 80)])
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 1.3, "inputContrast": 1.2])
        case "Forest":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 1.1, "inputBrightness": -0.1])
            outputImage = outputImage.applyingFilter("CIHueAdjust", parameters: ["inputAngle": 0.3])
        case "Polaroid":
            outputImage = outputImage.applyingFilter("CIPhotoEffectTransfer")
            outputImage = outputImage.applyingFilter("CIVignette", parameters: ["inputRadius": 1.5, "inputIntensity": 0.8])
        case "Arctic Aurora":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 1.6, "inputBrightness": 0.1])
            outputImage = outputImage.applyingFilter("CITemperatureAndTint", parameters: ["inputNeutral": CIVector(x: 6500, y: 0), "inputTargetNeutral": CIVector(x: 8500, y: -50)])
        case "Oil Painting":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 1.3, "inputContrast": 1.4])
            outputImage = outputImage.applyingFilter("CIGaussianBlur", parameters: ["inputRadius": 0.8])
        case "Haunted":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputBrightness": -0.4, "inputContrast": 1.8, "inputSaturation": 0.6])
            outputImage = outputImage.applyingFilter("CIVignette", parameters: ["inputRadius": 1.2, "inputIntensity": 1.0])
        case "Candy":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 2.0, "inputBrightness": 0.2, "inputContrast": 1.1])
            outputImage = outputImage.applyingFilter("CIHueAdjust", parameters: ["inputAngle": 0.5])
        case "Anime":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 1.6, "inputContrast": 1.3, "inputBrightness": 0.1])
        case "Synthwave":
            outputImage = outputImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1.2, y: 0.2, z: 0.8, w: 0),
                "inputGVector": CIVector(x: 0.1, y: 0.8, z: 1.2, w: 0),
                "inputBVector": CIVector(x: 0.8, y: 0.1, z: 1.5, w: 0)
            ])
        case "Vaporwave":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 1.8, "inputContrast": 1.2])
            outputImage = outputImage.applyingFilter("CIHueAdjust", parameters: ["inputAngle": 4.5])
        case "Blueprint":
            outputImage = outputImage.applyingFilter("CIColorInvert")
            outputImage = outputImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0, y: 0, z: 1, w: 0),
                "inputGVector": CIVector(x: 0, y: 0, z: 1, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: 1, w: 0)
            ])
        case "Infrared":
            outputImage = outputImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0, y: 1, z: 1, w: 0),
                "inputGVector": CIVector(x: 1, y: 0, z: 0, w: 0),
                "inputBVector": CIVector(x: 1, y: 0, z: 0, w: 0)
            ])
        case "Outrun":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 2.2, "inputContrast": 1.5])
            outputImage = outputImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1.3, y: 0.2, z: 0.5, w: 0),
                "inputGVector": CIVector(x: 0.1, y: 0.8, z: 1.1, w: 0),
                "inputBVector": CIVector(x: 0.8, y: 0.1, z: 1.2, w: 0)
            ])
        case "Duotone":
            outputImage = outputImage.applyingFilter("CIFalseColor", parameters: [
                "inputColor0": CIColor(red: 0.2, green: 0.1, blue: 0.8),
                "inputColor1": CIColor(red: 1.0, green: 0.6, blue: 0.2)
            ])
        case "Pixel":
            outputImage = outputImage.applyingFilter("CIPixellate", parameters: ["inputScale": 12.0])
        case "Chrome":
            outputImage = outputImage.applyingFilter("CIPhotoEffectChrome")
        case "Watercolor":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 1.4, "inputContrast": 0.8])
            outputImage = outputImage.applyingFilter("CIGaussianBlur", parameters: ["inputRadius": 1.2])
        case "Stardust":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 1.7, "inputBrightness": 0.2])
            outputImage = outputImage.applyingFilter("CIBloom", parameters: ["inputRadius": 6.0, "inputIntensity": 1.5])
        case "Moonlight":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 0.8, "inputBrightness": -0.1])
            outputImage = outputImage.applyingFilter("CITemperatureAndTint", parameters: ["inputNeutral": CIVector(x: 6500, y: 0), "inputTargetNeutral": CIVector(x: 9000, y: -30)])
        case "Toxic":
            outputImage = outputImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0.2, y: 1.2, z: 0.2, w: 0),
                "inputGVector": CIVector(x: 0.8, y: 1.5, z: 0.1, w: 0),
                "inputBVector": CIVector(x: 0.1, y: 0.2, z: 0.1, w: 0)
            ])
        case "Frostbite":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 0.6, "inputBrightness": 0.3, "inputContrast": 1.2])
            outputImage = outputImage.applyingFilter("CITemperatureAndTint", parameters: ["inputNeutral": CIVector(x: 6500, y: 0), "inputTargetNeutral": CIVector(x: 9500, y: -80)])
        case "Lava":
            outputImage = outputImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1.8, y: 0.5, z: 0.1, w: 0),
                "inputGVector": CIVector(x: 0.6, y: 0.8, z: 0.1, w: 0),
                "inputBVector": CIVector(x: 0.1, y: 0.1, z: 0.1, w: 0)
            ])
        case "Plasma":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 2.5, "inputContrast": 1.8])
            outputImage = outputImage.applyingFilter("CIHueAdjust", parameters: ["inputAngle": 3.8])
        case "Static":
            outputImage = outputImage.applyingFilter("CIRandomGenerator")
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 0.0, "inputContrast": 2.0])
        case "Hologram":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 1.8, "inputContrast": 1.3])
            outputImage = outputImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0.8, y: 1.2, z: 1.1, w: 0),
                "inputGVector": CIVector(x: 1.1, y: 0.8, z: 1.2, w: 0),
                "inputBVector": CIVector(x: 1.2, y: 1.1, z: 0.8, w: 0)
            ])
        case "Volcano":
            outputImage = outputImage.applyingFilter("CITemperatureAndTint", parameters: ["inputNeutral": CIVector(x: 6500, y: 0), "inputTargetNeutral": CIVector(x: 2500, y: 100)])
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 1.6, "inputContrast": 1.4])
        case "Northern Lights":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 1.8, "inputBrightness": 0.1])
            outputImage = outputImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0.3, y: 1.2, z: 0.8, w: 0),
                "inputGVector": CIVector(x: 0.8, y: 1.5, z: 0.3, w: 0),
                "inputBVector": CIVector(x: 1.1, y: 0.3, z: 1.2, w: 0)
            ])
            
        // Fantasy & Magic Effects
        case "Dragon Fire":
            outputImage = outputImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 2.0, y: 0.8, z: 0.1, w: 0),
                "inputGVector": CIVector(x: 1.0, y: 1.2, z: 0.2, w: 0),
                "inputBVector": CIVector(x: 0.1, y: 0.3, z: 0.1, w: 0)
            ])
            outputImage = outputImage.applyingFilter("CIBloom", parameters: ["inputRadius": 8.0, "inputIntensity": 2.0])
        case "Fairy Dust":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 1.8, "inputBrightness": 0.3])
            outputImage = outputImage.applyingFilter("CIBloom", parameters: ["inputRadius": 4.0, "inputIntensity": 1.5])
            outputImage = outputImage.applyingFilter("CIGaussianBlur", parameters: ["inputRadius": 0.5])
        case "Wizard":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 1.4, "inputContrast": 1.6])
            outputImage = outputImage.applyingFilter("CIVignette", parameters: ["inputRadius": 1.8, "inputIntensity": 0.9])
        case "Mermaid":
            outputImage = outputImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0.2, y: 0.8, z: 1.2, w: 0),
                "inputGVector": CIVector(x: 0.3, y: 1.3, z: 1.0, w: 0),
                "inputBVector": CIVector(x: 0.8, y: 0.9, z: 1.5, w: 0)
            ])
        case "Phoenix":
            outputImage = outputImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1.8, y: 0.6, z: 0.2, w: 0),
                "inputGVector": CIVector(x: 1.2, y: 0.8, z: 0.1, w: 0),
                "inputBVector": CIVector(x: 0.1, y: 0.2, z: 0.1, w: 0)
            ])
            outputImage = outputImage.applyingFilter("CIBloom", parameters: ["inputRadius": 10.0, "inputIntensity": 1.8])
            
        // Gemstone Effects
        case "Amethyst":
            outputImage = outputImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1.2, y: 0.4, z: 1.3, w: 0),
                "inputGVector": CIVector(x: 0.3, y: 0.6, z: 0.9, w: 0),
                "inputBVector": CIVector(x: 0.8, y: 0.3, z: 1.6, w: 0)
            ])
        case "Emerald":
            outputImage = outputImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0.2, y: 0.8, z: 0.1, w: 0),
                "inputGVector": CIVector(x: 0.4, y: 1.8, z: 0.3, w: 0),
                "inputBVector": CIVector(x: 0.1, y: 0.6, z: 0.2, w: 0)
            ])
        case "Ruby":
            outputImage = outputImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 2.0, y: 0.2, z: 0.1, w: 0),
                "inputGVector": CIVector(x: 0.1, y: 0.3, z: 0.1, w: 0),
                "inputBVector": CIVector(x: 0.1, y: 0.1, z: 0.2, w: 0)
            ])
        case "Sapphire":
            outputImage = outputImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0.1, y: 0.3, z: 1.2, w: 0),
                "inputGVector": CIVector(x: 0.2, y: 0.6, z: 1.0, w: 0),
                "inputBVector": CIVector(x: 0.8, y: 0.4, z: 2.0, w: 0)
            ])
            
        // Space & Cosmos
        case "Galaxy":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 2.0, "inputBrightness": -0.2])
            outputImage = outputImage.applyingFilter("CIBloom", parameters: ["inputRadius": 15.0, "inputIntensity": 2.5])
        case "Nebula":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 2.5, "inputContrast": 1.4])
            outputImage = outputImage.applyingFilter("CIGaussianBlur", parameters: ["inputRadius": 2.0])
            outputImage = outputImage.applyingFilter("CIBloom", parameters: ["inputRadius": 12.0, "inputIntensity": 2.0])
        case "Black Hole":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputBrightness": -0.8, "inputContrast": 3.0])
            outputImage = outputImage.applyingFilter("CIVignette", parameters: ["inputRadius": 0.5, "inputIntensity": 2.0])
        case "Supernova":
            outputImage = outputImage.applyingFilter("CIColorInvert")
            outputImage = outputImage.applyingFilter("CIBloom", parameters: ["inputRadius": 20.0, "inputIntensity": 3.0])
            
        // Elements & Forces
        case "Lightning":
            outputImage = outputImage.applyingFilter("CIColorInvert")
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputContrast": 3.0, "inputBrightness": 0.5])
        case "Tornado":
            outputImage = outputImage.applyingFilter("CITwirlDistortion", parameters: ["inputRadius": 300, "inputAngle": 3.14])
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 0.5, "inputContrast": 1.5])
        case "Nuclear":
            outputImage = outputImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0.2, y: 2.0, z: 0.1, w: 0),
                "inputGVector": CIVector(x: 1.8, y: 2.5, z: 0.2, w: 0),
                "inputBVector": CIVector(x: 0.1, y: 0.3, z: 0.1, w: 0)
            ])
            outputImage = outputImage.applyingFilter("CIBloom", parameters: ["inputRadius": 25.0, "inputIntensity": 3.0])
            
        // Technology & Digital
        case "Binary":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 0.0, "inputContrast": 3.0])
            outputImage = outputImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0.2, y: 1.0, z: 0.2, w: 0),
                "inputGVector": CIVector(x: 0.8, y: 2.0, z: 0.8, w: 0),
                "inputBVector": CIVector(x: 0.1, y: 0.2, z: 0.1, w: 0)
            ])
        case "Circuit":
            outputImage = outputImage.applyingFilter("CIEdges")
            outputImage = outputImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0.1, y: 0.8, z: 1.2, w: 0),
                "inputGVector": CIVector(x: 0.2, y: 1.5, z: 0.3, w: 0),
                "inputBVector": CIVector(x: 0.1, y: 0.2, z: 0.1, w: 0)
            ])
        case "Laser":
            outputImage = outputImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 2.0, y: 0.1, z: 0.1, w: 0),
                "inputGVector": CIVector(x: 0.1, y: 0.1, z: 0.1, w: 0),
                "inputBVector": CIVector(x: 0.1, y: 0.1, z: 0.1, w: 0)
            ])
            outputImage = outputImage.applyingFilter("CIBloom", parameters: ["inputRadius": 8.0, "inputIntensity": 2.0])
        case "8-Bit":
            outputImage = outputImage.applyingFilter("CIPixellate", parameters: ["inputScale": 20.0])
            outputImage = outputImage.applyingFilter("CIColorPosterize", parameters: ["inputLevels": 4])
            
        // Professional Photography Effects
        case "Bokeh":
            outputImage = outputImage.applyingFilter("CIGaussianBlur", parameters: ["inputRadius": 3.0])
            outputImage = outputImage.applyingFilter("CIBloom", parameters: ["inputRadius": 5.0, "inputIntensity": 1.2])
        case "Tilt Shift":
            outputImage = outputImage.applyingFilter("CIGaussianBlur", parameters: ["inputRadius": 8.0])
        case "HDR":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 1.6, "inputContrast": 1.4, "inputBrightness": 0.1])
            outputImage = outputImage.applyingFilter("CIHighlightShadowAdjust", parameters: ["inputHighlightAmount": 0.8, "inputShadowAmount": 1.2])
        case "Long Exposure":
            outputImage = outputImage.applyingFilter("CIMotionBlur", parameters: ["inputRadius": 10.0, "inputAngle": 0])
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputContrast": 1.3])
            
        // Extreme Effects
        case "Nuclear Blast":
            outputImage = outputImage.applyingFilter("CIColorInvert")
            outputImage = outputImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 3.0, y: 2.0, z: 0.1, w: 0),
                "inputGVector": CIVector(x: 2.5, y: 3.0, z: 0.2, w: 0),
                "inputBVector": CIVector(x: 0.1, y: 0.3, z: 0.1, w: 0)
            ])
            outputImage = outputImage.applyingFilter("CIBloom", parameters: ["inputRadius": 50.0, "inputIntensity": 5.0])
        case "Time Distortion":
            outputImage = outputImage.applyingFilter("CITwirlDistortion", parameters: ["inputRadius": 500, "inputAngle": 6.28])
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 2.0, "inputContrast": 1.5])
        case "Reality Glitch":
            outputImage = outputImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1.5, y: 0.3, z: 0.2, w: 0),
                "inputGVector": CIVector(x: 0.2, y: 1.0, z: 1.3, w: 0),
                "inputBVector": CIVector(x: 0.8, y: 0.2, z: 1.2, w: 0)
            ])
            outputImage = outputImage.applyingFilter("CIPixellate", parameters: ["inputScale": 15.0])
        case "Quantum Flux":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 3.0, "inputContrast": 2.0])
            outputImage = outputImage.applyingFilter("CIHueAdjust", parameters: ["inputAngle": 6.28])
            outputImage = outputImage.applyingFilter("CIBloom", parameters: ["inputRadius": 20.0, "inputIntensity": 3.0])
            
        // Art Movement Effects
        case "Impressionism":
            outputImage = outputImage.applyingFilter("CIGaussianBlur", parameters: ["inputRadius": 1.5])
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 1.4, "inputContrast": 0.8])
        case "Cubism":
            outputImage = outputImage.applyingFilter("CIEdges")
            outputImage = outputImage.applyingFilter("CIColorPosterize", parameters: ["inputLevels": 6])
        case "Surrealism":
            outputImage = outputImage.applyingFilter("CIColorInvert")
            outputImage = outputImage.applyingFilter("CIHueAdjust", parameters: ["inputAngle": 3.14])
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 2.0])
        case "Minimalism":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 0.3, "inputContrast": 1.8])
            outputImage = outputImage.applyingFilter("CIColorPosterize", parameters: ["inputLevels": 3])
            
        // Weather & Natural Phenomena
        case "Lightning Storm":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputBrightness": -0.4, "inputContrast": 2.0])
            outputImage = outputImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0.2, y: 0.3, z: 1.5, w: 0),
                "inputGVector": CIVector(x: 0.3, y: 0.4, z: 1.2, w: 0),
                "inputBVector": CIVector(x: 0.8, y: 0.9, z: 2.0, w: 0)
            ])
        case "Aurora":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 2.0, "inputBrightness": 0.2])
            outputImage = outputImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0.4, y: 1.5, z: 0.8, w: 0),
                "inputGVector": CIVector(x: 0.8, y: 2.0, z: 0.4, w: 0),
                "inputBVector": CIVector(x: 1.2, y: 0.4, z: 1.8, w: 0)
            ])
        case "Solar Flare":
            outputImage = outputImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 2.5, y: 1.0, z: 0.2, w: 0),
                "inputGVector": CIVector(x: 1.8, y: 1.5, z: 0.3, w: 0),
                "inputBVector": CIVector(x: 0.1, y: 0.2, z: 0.1, w: 0)
            ])
            outputImage = outputImage.applyingFilter("CIBloom", parameters: ["inputRadius": 30.0, "inputIntensity": 4.0])
            
        // Animal-Inspired Effects
        case "Tiger Stripes":
            outputImage = outputImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 1.5, y: 0.6, z: 0.1, w: 0),
                "inputGVector": CIVector(x: 0.8, y: 1.2, z: 0.2, w: 0),
                "inputBVector": CIVector(x: 0.1, y: 0.2, z: 0.1, w: 0)
            ])
        case "Peacock":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 2.5, "inputContrast": 1.3])
            outputImage = outputImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0.3, y: 1.0, z: 1.2, w: 0),
                "inputGVector": CIVector(x: 0.8, y: 1.8, z: 0.4, w: 0),
                "inputBVector": CIVector(x: 1.2, y: 0.3, z: 1.5, w: 0)
            ])
        case "Butterfly":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 2.0, "inputBrightness": 0.3])
            outputImage = outputImage.applyingFilter("CIBloom", parameters: ["inputRadius": 3.0, "inputIntensity": 1.0])
            
        // Music Genre Effects
        case "Jazz":
            outputImage = outputImage.applyingFilter("CISepiaTone", parameters: ["inputIntensity": 0.7])
            outputImage = outputImage.applyingFilter("CIVignette", parameters: ["inputRadius": 1.5, "inputIntensity": 0.6])
        case "Electronic":
            outputImage = outputImage.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: 0.2, y: 1.5, z: 1.8, w: 0),
                "inputGVector": CIVector(x: 1.8, y: 2.0, z: 0.2, w: 0),
                "inputBVector": CIVector(x: 1.5, y: 0.2, z: 2.0, w: 0)
            ])
        case "Rock":
            outputImage = outputImage.applyingFilter("CIColorControls", parameters: ["inputSaturation": 0.6, "inputContrast": 2.0, "inputBrightness": -0.2])
            
        default:
            break
        }
        
        return outputImage
    }
}

// MARK: - Camera Preview with Fixed Updates
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    @ObservedObject var cameraManager: CameraManager
    
    init(session: AVCaptureSession, cameraManager: CameraManager) {
        self.session = session
        self.cameraManager = cameraManager
    }
    
    // Legacy initializer for compatibility
    init(session: AVCaptureSession) {
        self.session = session
        self.cameraManager = CameraManager()
    }
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = UIColor.black
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        
        // Ensure proper orientation
        if let connection = previewLayer.connection, connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }
        
        view.layer.addSublayer(previewLayer)
        
        // Add filtered image view for overlay
        let filteredImageView = UIImageView(frame: view.bounds)
        filteredImageView.contentMode = .scaleAspectFill
        filteredImageView.clipsToBounds = true
        filteredImageView.tag = 100 // Tag for identification
        view.addSubview(filteredImageView)
        
        // Store the preview layer for later updates
        view.tag = 999
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            guard let previewLayer = uiView.layer.sublayers?.first(where: { $0 is AVCaptureVideoPreviewLayer }) as? AVCaptureVideoPreviewLayer else {
                // If preview layer doesn't exist, create it
                let newPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
                newPreviewLayer.videoGravity = .resizeAspectFill
                newPreviewLayer.frame = uiView.bounds
                
                if let connection = newPreviewLayer.connection, connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
                
                uiView.layer.addSublayer(newPreviewLayer)
                return
            }
            
            // Update existing preview layer
            previewLayer.frame = uiView.bounds
            previewLayer.videoGravity = .resizeAspectFill
            
            if let connection = previewLayer.connection, connection.isVideoOrientationSupported {
                connection.videoOrientation = .portrait
            }
            
            // Ensure the session is properly connected
            if previewLayer.session != session {
                previewLayer.session = session
            }
            
            // Update filtered image overlay
            if let filteredImageView = uiView.subviews.first(where: { $0.tag == 100 }) as? UIImageView {
                filteredImageView.frame = uiView.bounds
                
                if let filteredImage = cameraManager.filteredPreviewImage {
                    filteredImageView.image = filteredImage
                    filteredImageView.isHidden = false
                    previewLayer.opacity = 0.0 // Hide original preview when filter is active
                } else {
                    filteredImageView.isHidden = true
                    previewLayer.opacity = 1.0 // Show original preview when no filter
                }
            }
        }
    }
}
