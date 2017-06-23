//
//  SkStViewController.swift
//  Dict
//
//  Created by Sviatoslav Zimine on 6/20/17.
//  Copyright © 2017 szimine. All rights reserved.
//

import UIKit

import SpeechKit


class SkStViewController: UIViewController, UITextFieldDelegate,  UITextViewDelegate,  SKTransactionDelegate
{
    

    
    //@IBOutlet weak var noteTitleTextField: UITextField? //we might not need the title textField
    
    @IBOutlet weak var statusTextView: UITextView?
    @IBOutlet weak var memoTextView: UITextView?
    
    @IBOutlet weak var clearButtonItem: UIBarButtonItem?
    @IBOutlet weak var recTogButtonItem: UIBarButtonItem?
    @IBOutlet weak var sendButtonItem: UIBarButtonItem?
    
    
    var noteBodyContent:String!
    var tempNoteBodyContent:String!
    
    var noteTxContent:String!
    var prevNoteTxContent:String!
    
    //state
    enum SKState:String {
        case Idle
        case Listening
        case Processing
    }
    
    
    var languages: [String:String]! = ["eng-USA":"English",
                                       "fra-FRA": "French",
                                       "ger-DEU": "German",
                                       "spa-ESP": "Spanish"]
    var language: String!
    var noteTitle: String! //potentially useful
    
    var recognitionType: String!
    
    var state = SKState.Idle
    
    var progressiveResults: Bool!
    
    var skSession:SKSession?
    var skTransaction:SKTransaction?
    
    var endpointer: SKTransactionEndOfSpeechDetection!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        clearButtonItem!.tintColor = .brown
        recTogButtonItem!.tintColor = .brown
        sendButtonItem!.tintColor = .brown
        
        
        let borderColor : UIColor = UIColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1.0)
        memoTextView!.layer.borderWidth = 0.5
        memoTextView!.layer.borderColor = borderColor.cgColor
        memoTextView!.layer.cornerRadius = 5.0
        
        
        language = LANGUAGE // from config
        
        
        
        // params for speach recognition
        recognitionType = SKTransactionSpeechTypeDictation
        progressiveResults = true //// progressive false
        
        // endpointer = .none //.short,  .long
        endpointer = SKTransactionEndOfSpeechDetection.none
        
        state = .Idle
        //self.statusTextView!.text = state.rawValue
        
        noteBodyContent = ""  //initial value at app start
        tempNoteBodyContent = ""
        
        self.memoTextView!.text = noteBodyContent
        
        
        skTransaction = nil
        // create a session
        skSession = SKSession(url: URL(string:SKSServerUrl), appToken: SKSAppKey)
        
        if (skSession == nil){
            self.setStatus(text: "Failed to initialize SpeechKit session...", type: .Info)
        }
        
        loadEarcons()
        //## nuance initialization finished
        
        memoTextView!.delegate = self // assign uitextview delegate
        
        // Events used to hide keyboard
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        
        // Status must be read-only
        self.statusTextView?.isEditable = false
    }
    
    
    // Calls this function when the tap is recognized.
    func dismissKeyboard() {
        // Causes the view (or one of its embedded text fields) to resign the first responder status.
        view.endEditing(true)
    }
    
    
    override func didReceiveMemoryWarning() {
        setStatus(text: "You should save your Note or close applications on your mobile device as the memory of your device is short!", type: .Warning)
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    func textViewDidBeginEditing(_ textView: UITextView){
        animateViewMoving(true, moveValue: 200)
        //stopping dragon trasaction
        if let sktx = skTransaction {
          sktx.stopRecording()
        }
    }
    
    
    func textViewDidEndEditing(_ textView: UITextView){
        animateViewMoving(false, moveValue: 200)
    }
    
    
    // Lifting the view up
    func animateViewMoving (_ up:Bool, moveValue :CGFloat){
        let movementDuration:TimeInterval = 0.3
        let movement:CGFloat = ( up ? -moveValue : moveValue)
        UIView.beginAnimations( "animateView", context: nil)
        UIView.setAnimationBeginsFromCurrentState(true)
        UIView.setAnimationDuration(movementDuration )
        
        self.view.frame = self.view.frame.offsetBy(dx: 0,  dy: movement)
        
        
        UIView.commitAnimations()
    }
    
    
    @IBAction func clearLastLine(_ sender: UIBarButtonItem){
        
        var memoLines = noteBodyContent.components(separatedBy: "\n")
        if memoLines.count > 0 || !memoLines[0].isEmpty {
            let lastLine = memoLines.removeLast()
            if (lastLine.isEmpty && memoLines.count > 0) {
                memoLines.removeLast()
            }
            let joined = memoLines.joined(separator: "\n")
            noteBodyContent = joined
            memoTextView!.text = noteBodyContent
        }
    }
    
    
    @IBAction func toggleRecording(_ sender: UIBarButtonItem) {
        switch state {
            case .Idle: startRecording()
            case .Listening: stopRecording()
            case .Processing: cancel()
        }
    }
    
    
    /*!
     Extract the first line of the text as the subject
    */
    func extractSubject() -> String {
        let firstLines = memoTextView!.text.components(separatedBy: "\n")
        let firstSentences = firstLines[0].components(separatedBy: ".")
        let subject = firstSentences[0]
        return subject.characters.count < SUBJECT_MAX_SIZE ? subject : String(
            subject.characters.dropLast(subject.characters.count - SUBJECT_MAX_SIZE)
        )
    }
    
    
    @IBAction func onSend(_ sender: UIBarButtonItem) {
        let fullText: String = memoTextView!.text
        if (!fullText.isEmpty)  {
            let noteTitle = extractSubject()
            
            let parameters = ["text": fullText, "title": noteTitle] as Dictionary<String, String>
            let url = URL(string: SERVICE_URL_RECORD)!
            let session = URLSession.shared

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            
            do {
                // pass dictionary to nsdata object and set it as request body
                request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: .prettyPrinted)
                
            } catch let error {
                self.setStatus(text: "Unable to submit the Note: " + error.localizedDescription, type: .Error)
            }
            
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            
            // create dataTask using the session object to send data to the server
            let task = session.dataTask(with: request as URLRequest, completionHandler: { data, response, error in
                guard error == nil else {
                    return
                }
                
                guard let data = data else {
                    return
                }
                
                do {
                    // should be a valid Json:
                    if let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] {
                        // we don't do anything with the JSON...
                        print(json)
                        //
                        DispatchQueue.main.async {
                            self.setStatus(text: "The Note has been saved successfully", type: .Info)
                            self.memoTextView?.text = ""
                        }
                    }
                    
                } catch let error {
                    DispatchQueue.main.async {
                        self.setStatus(text: "Unable to save the Note: " + error.localizedDescription, type: .Error)
                    }
                }
            })
            task.resume()
        }
        
    }
    
    
    func startRecording(){
        
        // make sure the screen is not locked if the user dictate for too long...
        UIApplication.shared.isIdleTimerDisabled = true
        
        let options = NSMutableDictionary()
        
        if(progressiveResults!){
                    options.setValue(SKTransactionResultDeliveryProgressive, forKey: SKTransactionResultDeliveryKey)
        }
        // fire transaction
        skTransaction = skSession!.recognize(withType: recognitionType,
                                             detection: endpointer,
                                             language: language,
                                             options: options as! [AnyHashable : Any],
                                             delegate: self)
    }
    
    func stopRecording() {
        // screen locking re-enabled now as the user is done with dictation
        UIApplication.shared.isIdleTimerDisabled = false
        // stop recording user
        skTransaction!.stopRecording()
    }
    
    func cancel() {
        // This will only cancel if we have not received a response from the server yet.
        UIApplication.shared.isIdleTimerDisabled = false
        skTransaction!.cancel()
        
    }
    
    
    
    // SKTransactionDelegate
    
    // when recording began
    func transactionDidBeginRecording(_ transaction: SKTransaction!) {
        log("transactionDidBeginRecording")
        self.recTogButtonItem!.title = "Stop"
        state = .Listening
        self.setStatus(text: state.rawValue, type: .Info)
        //startPollingVolume()
        
        noteBodyContent = memoTextView!.text  // bug fix for keyboard modifs
        tempNoteBodyContent = noteBodyContent
    }
    
    // when recording is stopped
    func transactionDidFinishRecording(_ transaction: SKTransaction!) {
        log("transactionDidFinishRecording")
        
        state = .Processing
        self.setStatus(text: "Finished recording "  +  state.rawValue + "..", type: .Info)
        
        self.recTogButtonItem!.title = "Cancel"
        //stopPollingVolume()
    }
    
    // when tx payload delivered
    func transaction(_ transaction: SKTransaction!, didReceive recognition: SKRecognition!) {
        log(String(format: "didReceiveRecognition: %@", arguments: [recognition.text]))
        
        log2textBuffer(String(format: "%@", arguments:[recognition.text]))   //only call
    }
    // tx returns service data
    func transaction(_ transaction: SKTransaction!, didReceiveServiceResponse response: [AnyHashable : Any]!) {
        log(String(format: "didReceiveServiceResponse: %@", arguments: [response]))
    }
    // tx interpretation finished
    func transaction(_ transaction: SKTransaction!, didFinishWithSuggestion suggestion: String) {
        log("didFinishWithSuggestion")
        
        self.setStatus(text: "Finished " + state.rawValue.lowercased() + " ", type: .Info)
        
        state = .Idle
        //self.setStatus(text: self.statusTextView!.text.appendingFormat("%@", state.rawValue), type: .Info) /no idle in status
                                                                              
        self.recTogButtonItem!.title = "Record"
        
        noteBodyContent = tempNoteBodyContent
        if(progressiveResults){
                noteBodyContent! += "\n"
                memoTextView!.text = noteBodyContent
        }
        
        resetTransaction()
    }
    
    func transaction(_ transaction: SKTransaction!, didFailWithError error: Error!, suggestion: String) {
        log(String(format: "didFailWithError: %@. %@", arguments: [error.localizedDescription, suggestion]))
        
        // Something went wrong. Ensure that your credentials are correct.
        // The user could also be offline, so be sure to handle this case appropriately.
        self.setStatus(text: "Finished " + state.rawValue.lowercased() + " failed.. ", type: .Info)
        state = .Idle
        //self.setStatus(text: self.statusTextView!.text.appendingFormat("%@", state.rawValue), type: .Info) //no idle in status
        
        self.recTogButtonItem!.title = "Record"
        
        state = .Idle
        resetTransaction()
        
    }
    
    
    func resetTransaction() {
        OperationQueue.main.addOperation({  //main thread
            self.skTransaction = nil
        })
    }
    
    // Volume level
    
    
    // Helpers
    
    func log(_ message: String) {
        print( message)
    }
    
    func log2textBuffer(_ message: String){
        noteTxContent = message
        if (!progressiveResults){
            tempNoteBodyContent = tempNoteBodyContent.appendingFormat("%@\n", noteTxContent)
        }else{ //progressive results
            tempNoteBodyContent = noteBodyContent.appendingFormat("%@", noteTxContent)
        }
        memoTextView!.text = tempNoteBodyContent
    }
    
    func loadEarcons() {
        let startEarconPath = Bundle.main.path(forResource: "sk_start", ofType: "pcm")
        let stopEarconPath = Bundle.main.path(forResource: "sk_stop", ofType: "pcm")
        let errorEarconPath = Bundle.main.path(forResource: "sk_error", ofType: "pcm")
        let audioFormat = SKPCMFormat()
        audioFormat.sampleFormat = .signedLinear16
        audioFormat.sampleRate = 16000
        audioFormat.channels = 1
        
        skSession!.startEarcon = SKAudioFile(url: URL(fileURLWithPath: startEarconPath!), pcmFormat: audioFormat)
        skSession!.endEarcon = SKAudioFile(url: URL(fileURLWithPath: stopEarconPath!), pcmFormat: audioFormat)
        skSession!.errorEarcon = SKAudioFile(url: URL(fileURLWithPath: errorEarconPath!), pcmFormat: audioFormat)
    }
    
    // Status bar management
    func setStatus(text: String, type: StatusBarMessageType) {
        self.statusTextView!.text = text
        if (type == .Info) {
            self.statusTextView!.textColor = UIColor.black
        }
        else if type == .Warning {
            self.statusTextView!.textColor = UIColor.orange
        }
        else {
            self.statusTextView!.textColor = UIColor.red
        }
    }
    
    enum StatusBarMessageType {
        case Info
        case Error
        case Warning
    }
    

}

