import UIKit
import MapKit
import CoreLocation

class secondViewController: UIViewController {
    var destinationCoordinates: CLLocationCoordinate2D?

    @IBOutlet weak var mapView: MKMapView!
    let locationManager = CLLocationManager()
    
    override func viewDidLoad() {
            super.viewDidLoad()
            
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.requestWhenInUseAuthorization()
        }
    
    override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            
            if let destinationCoordinates = destinationCoordinates {
                mapRoute(destinationCoordinates)
            }
        }
    
    func mapRoute(_ destinationCord: CLLocationCoordinate2D) {
            guard let userLocation = locationManager.location?.coordinate else {
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
            directions.calculate { [weak self] (response, error) in
                guard let self = self, let response = response else {
                    if let error = error {
                        print("Something Went Wrong: \(error)")
                    }
                    return
                }

                // Clear any previous overlays and annotations
                self.mapView.removeOverlays(self.mapView.overlays)
                self.mapView.removeAnnotations(self.mapView.annotations)

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
        }
    }

extension secondViewController: MKMapViewDelegate {
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKPolyline {
            let renderer = MKPolylineRenderer(overlay: overlay)
            renderer.strokeColor = .blue
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }
}

extension secondViewController: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location Manager Error: \(error.localizedDescription)")
    }
}
