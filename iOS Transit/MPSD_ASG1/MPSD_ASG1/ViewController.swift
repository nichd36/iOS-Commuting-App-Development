import UIKit
import MapKit
import CoreLocation
import Speech
import AVFoundation
import UserNotifications
import CoreBluetooth

class ViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate, SFSpeechRecognizerDelegate, UNUserNotificationCenterDelegate
{
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var searchForAddress: UITextField!
    @IBOutlet weak var exitButton: UIButton!
    @IBOutlet weak var zoomIn: UIButton!
    @IBOutlet weak var zoomOut: UIButton!
    @IBOutlet weak var searchButton: UIImageView!
    @IBOutlet weak var location: UITextField!
    @IBOutlet weak var destination: UITextField!
    @IBOutlet weak var currentLocationButton: UIButton!
    @IBOutlet weak var busButton: UIButton!
    @IBOutlet weak var lrtButton: UIButton!
    @IBOutlet weak var mrtButton: UIButton!
    @IBOutlet weak var startButton: UIButton!
    @IBOutlet weak var searchText: UITextField!
    @IBOutlet weak var voiceToTextButton: UIButton!
    @IBOutlet weak var estimatedDepartureTime: UITextField!
    
    var locationManager = CLLocationManager()
    var selectedTransportationMode: TransportationMode?
    var centralManager: CBCentralManager!
    var destinationCoordinates: CLLocationCoordinate2D?
    var savedAnnotations: [MKAnnotation] = []
    var savedOverlays: [MKOverlay] = []
    
    let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ms-MY"))
    let audioEngine = AVAudioEngine()
    
    enum TransportationMode {
        case lrt
        case bus
        case mrt
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestAlwaysAuthorization()
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
        
        mapView.delegate = self
        
        zoomIn.setTitle("+", for: .normal)
        zoomIn.backgroundColor = UIColor.systemGray
        zoomIn.layer.cornerRadius = 5
        zoomIn.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        
        zoomOut.setTitle("-", for: .normal)
        zoomOut.backgroundColor = UIColor.systemGray
        zoomOut.layer.cornerRadius = 5
        zoomOut.contentEdgeInsets = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        
        searchForAddress.delegate = self
        searchForAddress.backgroundColor = UIColor.white
        searchForAddress.textColor = UIColor.black
        searchForAddress.layer.cornerRadius = searchForAddress.frame.size.height / 2
        searchForAddress.layer.borderColor = UIColor.gray.cgColor
        searchForAddress.layer.borderWidth = 1.0
        searchForAddress.layer.masksToBounds = true

        exitButton.isHidden = true
        exitButton.layer.cornerRadius = exitButton.frame.size.height / 2
        
        location.layer.borderColor = UIColor.gray.cgColor
        location.layer.borderWidth = 1.0
        location.layer.masksToBounds = true
        
        destination.layer.borderColor = UIColor.gray.cgColor
        destination.layer.borderWidth = 1.0
        destination.layer.masksToBounds = true
        
        estimatedDepartureTime.layer.borderColor = UIColor.gray.cgColor
        estimatedDepartureTime.layer.borderWidth = 1.0
        estimatedDepartureTime.layer.masksToBounds = true
        
        mapView.showsUserLocation = true
        
        location.delegate = self
        location.addTarget(self, action: #selector(locationTextFieldEditingDidBegin), for: .editingDidBegin)
        destination.delegate = self
        destination.addTarget(self, action: #selector(destinationTextFieldEditingDidBegin), for: .editingDidBegin)
        currentLocationButton.addTarget(self, action: #selector(currentLocationButtonTapped), for: .touchUpInside)
        startButton.addTarget(self, action: #selector(startButtonTapped(_:)), for: .touchUpInside)
        
        requestSpeechRecognitionAuthorization()
        estimatedDepartureTime.isEnabled = false
        
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { (granted, error) in
               if !granted {
                   print("User notification authorization denied.")
               }
           }
        UNUserNotificationCenter.current().delegate = self
/*
 
 Attempted to connect bluetooth to application but it doesn't allow due to the bluetooth device is not supported
 
        centralManager = CBCentralManager(delegate: self, queue: nil)
 
 */
    }

    override func viewDidAppear(_ animated: Bool)
    {
        super.viewDidAppear(animated)
        zoomToUserLocation()
    }
    
    @IBAction func busButtonTapped(_ sender: Any)
    {
        if selectedTransportationMode == .bus
        {
            selectedTransportationMode = nil
        }
        else
        {
            selectedTransportationMode = .bus
        }
        updateButtonColor()
    }
    
    @IBAction func lrtButtonTapped(_ sender: Any)
    {
        if selectedTransportationMode == .lrt
        {
            selectedTransportationMode = nil
        }
        else
        {
            selectedTransportationMode = .lrt
        }
        updateButtonColor()
    }
    
    @IBAction func trackBus(_ sender: Any) {
        let web = WebViewController(url: URL(string: "https://myrapidbus.prasarana.com.my/kiosk")!, title: "Bus Map")
        let navWeb = UINavigationController(rootViewController: web)
        present(navWeb, animated: true)
    }
    
    @IBAction func mrtButtonTapped(_ sender: Any)
    {
        if selectedTransportationMode == .mrt
        {
            selectedTransportationMode = nil
        }
        else
        {
            selectedTransportationMode = .mrt
        }
        updateButtonColor()
    }
    
    
    func updateButtonColor()
    {
        lrtButton.backgroundColor = UIColor.clear
        busButton.backgroundColor = UIColor.clear
        mrtButton.backgroundColor = UIColor.clear

        switch selectedTransportationMode
        {
        case .lrt:
            lrtButton.backgroundColor = UIColor.gray
        case .bus:
            busButton.backgroundColor = UIColor.gray
        case .mrt:
            mrtButton.backgroundColor = UIColor.gray
        case .none:
            break
        }
    }
    
    @IBAction func voiceToTextButtonTapped(_ sender: Any)
    {
        if isSpeechRecognitionAvailable()
        {
            startSpeechRecognition()
        }
    }
    
    func startSpeechRecognition()
    {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .default, options: [])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to set up audio session: \(error)")
            return
        }
        
        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        let inputNode = audioEngine.inputNode
        let inputNodeBus = inputNode.inputFormat(forBus: 0)
        
        recognitionRequest.shouldReportPartialResults = true
        
        let recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest, resultHandler: { [weak self] (result, error) in
            guard let self = self else { return }
            
            var isFinal = false
            
            if let result = result {
                self.destination.text = result.bestTranscription.formattedString
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.stopSpeechRecognition()
            }
        })
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        if recordingFormat.sampleRate != inputNodeBus.sampleRate {
            guard let converter = AVAudioConverter(from: inputNodeBus, to: recordingFormat) else {
                print("Unable to create audio converter")
                return
            }
            
            inputNode.removeTap(onBus: 0)
            
            let bufferSize = AVAudioFrameCount(4096)
            inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputNodeBus) { (buffer, time) in
                let convertedBuffer = AVAudioPCMBuffer(pcmFormat: recordingFormat, frameCapacity: bufferSize)!
                
                var error: NSError?
                let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                    outStatus.pointee = AVAudioConverterInputStatus.haveData
                    return buffer
                }
                
                converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputBlock)
                recognitionRequest.append(convertedBuffer)
            }
        } else {
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer, _) in
                recognitionRequest.append(buffer)
            }
        }
        
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    func stopSpeechRecognition()
    {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
    }

    func isSpeechRecognitionAvailable() -> Bool
    {
        return SFSpeechRecognizer.authorizationStatus() == .authorized && speechRecognizer != nil
    }

    func requestSpeechRecognitionAuthorization()
    {
        SFSpeechRecognizer.requestAuthorization { (status) in
            DispatchQueue.main.async {
                if status == .authorized {
                    self.voiceToTextButton.isEnabled = true
                } else {
                    self.voiceToTextButton.isEnabled = false
                }
            }
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowSecondScreen" {
            if let destinationVC = segue.destination as? secondViewController {
                // Pass the destinationCoordinates to the second view controller
                destinationVC.destinationCoordinates = self.destinationCoordinates
            }
        }
    }
    
    @IBAction func startButtonTapped(_ sender: Any)
    {
        guard let destinationText = destination.text, let locationText = location.text else {
                return
            }

            if destinationText == "Choose destination" || locationText == "Your location" {
                return
            }

            if selectedTransportationMode == nil {
                return
            }

            getAddress()
            searchButton.isHidden = true

            let transportationSpeed = getTransportationSpeed()
            let geoCoder = CLGeocoder()
            geoCoder.geocodeAddressString(destinationText) { [weak self] (placemarks, error) in
                guard let self = self, let placemark = placemarks?.first else {
                    return
                }
                
                guard let destinationLocation = placemark.location else {
                    return
                }
                let userLocation = self.locationManager.location
                let distance = userLocation?.distance(from: destinationLocation) ?? 0.0
                let estimatedTime = distance / transportationSpeed
                let arrivalTime = Date().addingTimeInterval(estimatedTime)
                let departureTime = arrivalTime.addingTimeInterval(-300)

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "hh:mm a"
                let formattedDepartureTime = dateFormatter.string(from: departureTime)

                DispatchQueue.main.async {
                    self.updateEstimatedDepartureTime(formattedDepartureTime)
                    self.scheduleUserNotification(for: departureTime)
                    if let destinationCoordinates = self.destinationCoordinates {
                                    self.performSegue(withIdentifier: "ShowSecondScreen", sender: self)
                        }
                }
            }
    }
    
    func updateEstimatedDepartureTime(_ timeString: String) {
        estimatedDepartureTime.text = "Estimated Departure Time: \(timeString)"
    }
    
    func scheduleUserNotification(for date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Time to Depart"
        content.body = "Estimated departure time is approaching."
        content.sound = UNNotificationSound.default

        let triggerDate = Calendar.current.date(byAdding: .minute, value: -2, to: date)!
        let trigger = UNCalendarNotificationTrigger(dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: triggerDate), repeats: false)
        let request = UNNotificationRequest(identifier: "departureNotification", content: content, trigger: trigger)

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }
    
    func getTransportationSpeed() -> CLLocationDistance {
        switch selectedTransportationMode {
        case .bus:
            return 40.0 * 1000.0 / 3600.0
        case .lrt:
            return 80.0 * 1000.0 / 3600.0
        case .mrt:
            return 100.0 * 1000.0 / 3600.0
        case .none:
            return 0.0
        }
    }
    
    @IBAction func currentLocationButtonTapped(_ sender: Any?)
    {
        guard let userLocation = locationManager.location
        else
        {
            print("Unable to retrieve current location")
            return
        }
        let geoCoder = CLGeocoder()
                geoCoder.reverseGeocodeLocation(userLocation) { (placemarks, error) in
                    guard error == nil, let placemark = placemarks?.first else {
                        print("Reverse geocoding failed with error: \(error?.localizedDescription ?? "")")
                        return
                    }
                    let address = self.buildAddressString(from: placemark)
                    DispatchQueue.main.async {
                        self.location.text = address
                    }
                }
        currentLocationButton.isHidden = true
    }
    
    func buildAddressString(from placemark: CLPlacemark) -> String {
            var address = ""

            if let name = placemark.name {
                address += name
            }

            if let thoroughfare = placemark.thoroughfare {
                address += ", " + thoroughfare
            }

            if let subThoroughfare = placemark.subThoroughfare {
                address += ", " + subThoroughfare
            }

            if let locality = placemark.locality {
                address += ", " + locality
            }

            if let postalCode = placemark.postalCode {
                address += ", " + postalCode
            }

            if let administrativeArea = placemark.administrativeArea {
                address += ", " + administrativeArea
            }

            if let country = placemark.country {
                address += ", " + country
            }
            return address
        }
    
    @objc func locationTextFieldEditingDidBegin()
    {
        if location.text == "Your location"
        {
            location.text = ""
        }
    }
    
    @objc func destinationTextFieldEditingDidBegin() {
            if destination.text == "Choose destination" {
                destination.text = ""
            }
        }
    
    @IBAction func zoomInButtonTapped(_ sender: Any)
    {
        let span = mapView.region.span
        let newSpan = MKCoordinateSpan(latitudeDelta: span.latitudeDelta * 0.5, longitudeDelta: span.longitudeDelta * 0.5)
        let newRegion = MKCoordinateRegion(center: mapView.region.center, span: newSpan)
        mapView.setRegion(newRegion, animated: true)
    }
    
    
    @IBAction func zoomOutButtonTapped(_ sender: Any)
    {
        let span = mapView.region.span
        let newSpan = MKCoordinateSpan(latitudeDelta: span.latitudeDelta * 2, longitudeDelta: span.longitudeDelta * 2)
        let newRegion = MKCoordinateRegion(center: mapView.region.center, span: newSpan)
        mapView.setRegion(newRegion, animated: true)
    }

    
    @IBAction func exitButtonTapped(_ sender: Any)
    {
        searchForAddress.text = "Search here"
        searchForAddress.isHidden = false
        exitButton.isHidden = true
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        searchButton.isHidden = false
        zoomToUserLocation()
        location.text = "Your location"
        destination.text = "Choose destination"
        currentLocationButton.isHidden = false
        estimatedDepartureTime.text = "Estimated Departure Time:"
        selectedTransportationMode = nil
        updateButtonColor()
    }
    
    func getAddress()
    {
        let geoCoder = CLGeocoder()

           geoCoder.geocodeAddressString(destination.text!) { (placemarks, error) in
               guard let placemarks = placemarks, let location = placemarks.first?.location else {
                   print("Location Not Found")
                   return
               }
               print(location)
               self.mapThis(destinationCord: location.coordinate)
           }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation])
    {
        guard let location = locations.last else { return }
        let userLocation = CLLocationCoordinate2D(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        mapView.setCenter(userLocation, animated: true)
        if let annotationView = mapView.view(for: mapView.userLocation) {
            annotationView.transform = CGAffineTransform(rotationAngle: CGFloat(location.course.degreesToRadians()))
        }
    }
    
    func mapThis(destinationCord: CLLocationCoordinate2D)
    {
        guard let userLocation = locationManager.location?.coordinate
        else
        {
            print("Location Not Found")
            return
        }

        let soucePlaceMark = MKPlacemark(coordinate: userLocation)
        let destPlaceMark = MKPlacemark(coordinate: destinationCord)
        let sourceItem = MKMapItem(placemark: soucePlaceMark)
        let destItem = MKMapItem(placemark: destPlaceMark)
        let destinationRequest = MKDirections.Request()
        destinationRequest.source = sourceItem
        destinationRequest.destination = destItem
        destinationRequest.transportType = .automobile
        destinationRequest.requestsAlternateRoutes = true
        let directions = MKDirections(request: destinationRequest)
        directions.calculate { (response, error) in
            guard let response = response
            else
            {
                if let error = error
                {
                    print("Something Went Wrong: \(error)")
                }
                return
            }
            let route = response.routes[0]
            self.mapView.addOverlay(route.polyline)
            let padding: CGFloat = 20.0
            let mapRect = route.polyline.boundingMapRect
            let zoomRect = MKMapRect(
                x: mapRect.origin.x - padding,
                y: mapRect.origin.y - padding,
                width: mapRect.size.width + 2 * padding,
                height: mapRect.size.height + 2 * padding
            )
            self.mapView.setVisibleMapRect(zoomRect, edgePadding: UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20), animated: true)

            let destinationAnnotation = MKPointAnnotation()
            destinationAnnotation.coordinate = destinationCord
            self.mapView.addAnnotation(destinationAnnotation)
        }
        searchForAddress.isHidden = true
        exitButton.isHidden = false
    }
    
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer
    {
        if overlay is MKPolyline {
            let renderer = MKPolylineRenderer(overlay: overlay)
            renderer.strokeColor = .blue
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }

    func zoomToUserLocation()
    {
                guard let userLocation = locationManager.location?.coordinate else { return }
                let region = MKCoordinateRegion(center: userLocation, latitudinalMeters: 1000, longitudinalMeters: 1000)
                mapView.setRegion(region, animated: true)
    }
}

extension ViewController: UITextFieldDelegate
{
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == searchForAddress {
            textField.text = ""
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()

            if textField == searchText {
                guard let searchAddress = searchText.text else {
                    print("Search address is empty")
                    return true
                }

                let geoCoder = CLGeocoder()
                geoCoder.geocodeAddressString(searchAddress) { [weak self] (placemarks, error) in
                    guard let self = self else { return }

                    if let error = error {
                        print("Geocoding error: \(error.localizedDescription)")
                        return
                    }

                    if let placemark = placemarks?.first, let location = placemark.location {
                        self.addMarkerAtLocation(coordinate: location.coordinate)
                        self.zoomToLocation(coordinate: location.coordinate)
                        self.destination.text = placemark.name ?? "Choose destination"
                        self.currentLocationButtonTapped(nil)
                    } else {
                        print("No placemark found for the provided search address.")
                    }
                }

                searchButton.isHidden = true
            } else if textField == destination {
                startButtonTapped(textField)
            }

            return true
    }
    
    func addMarkerAtLocation(coordinate: CLLocationCoordinate2D)
    {
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        mapView.addAnnotation(annotation)
    }
    
    func zoomToLocation(coordinate: CLLocationCoordinate2D)
    {
        let region = MKCoordinateRegion(center: coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000)
        mapView.setRegion(region, animated: true)
        
        exitButton.isHidden = false
        searchText.isHidden = true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField)
    {
        if textField.text?.isEmpty ?? true {
            if textField == location {
                textField.text = "Your location"
                currentLocationButton.isHidden = false
            } else if textField == destination {
                textField.text = "Choose destination"
            }
        } else {
            let isAllFieldsEmpty = [searchForAddress, location, destination].allSatisfy { $0?.text?.isEmpty ?? true }
            currentLocationButton.isHidden = !isAllFieldsEmpty
        }
    }
}

extension Double
{
    func degreesToRadians() -> Double
    {
        return self * .pi / 180.0
    }
}

/*
 
 Attempted to connect bluetooth to application but it doesn't allow due to the bluetooth device is not supported
 
 extension ViewController: CBCentralManagerDelegate {
 func centralManagerDidUpdateState(_ central: CBCentralManager) {
 if central.state == .poweredOn {
 centralManager.scanForPeripherals(withServices: nil, options: nil)
 } else {
 }
 }
 
 func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
 if peripheral.name == "FangKhai's Airpod" {
 centralManager.stopScan()
 centralManager.connect(peripheral, options: nil)
 }
 }
 }
 
 */
