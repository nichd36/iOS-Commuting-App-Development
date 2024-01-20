//
//  ContactUsViewController.swift
//  MPSD_ASG1
//
//  Created by Nicholas Dylan on 27/07/2023.
//

import UIKit
import FirebaseDatabase

class ContactUsViewController: UIViewController {
    
    @IBOutlet weak var newsletter: UISwitch!
    @IBOutlet weak var dob: UIDatePicker!
    @IBOutlet weak var name: UITextField!
    @IBOutlet weak var email: UITextField!
    @IBOutlet weak var gender: UIButton!
    @IBOutlet weak var message: UITextField!
    @IBOutlet weak var nationality: UISegmentedControl!
    private let db = Database.database().reference()
    
    
    override func viewDidLoad() {
        setupGender()
    }
    
    func dateToString() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: dob.date)
        return dateString
    }
    
    func getButtonTitle() -> String? {
        let buttonTitle = gender.title(for: .normal)
        return buttonTitle
    }

    @IBAction func addEntry(_ sender: Any) {
        
        let inquiry: [String: Any] = [
            "name": name.text!,
            "email": email.text!,
            "date_of_birth": dateToString(),
            "gender": getButtonTitle()!,
            "nationality": nationality.selectedSegmentIndex,
            "newsletter": newsletter.isOn,
            "message": message.text!
        ]
        
        db.child("Inquiry/\(name.text!)_\(Int.random(in: 0..<1000))").setValue(inquiry)
            
        navigationController?.popViewController(animated: true)
    }
    
    
    
    
    
    func setupGender(){
        let option = {(action: UIAction) in print(action.title)}
        
        gender.menu = UIMenu(children: [
        UIAction(title: "Male", handler: option),
        UIAction(title: "Female", handler: option),
        UIAction(title: "Others", handler: option),
        UIAction(title: "Prefer not to say", handler: option)])
        
        gender.showsMenuAsPrimaryAction = true
        gender.changesSelectionAsPrimaryAction = true
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
