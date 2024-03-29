// This code was generated by a tool
// Changes to this file may cause incorrect behavior and will be lost if the code is regenerated

class EnvConfig {
    private let config: NSDictionary

    init(dictionary: NSDictionary) { config = dictionary }

    convenience init() {
        var nsDictionary: NSDictionary?
        if let path = Bundle.main.path(forResource: "EnvConfig", ofType: "plist") {
            nsDictionary = NSDictionary(contentsOfFile: path)
        }
        self.init(dictionary: nsDictionary!)
    }

    var facebookAppId : String { return config["FACEBOOK_APP_ID"] as! String }
    var fbLoginProtocolScheme : String { return config["FB_LOGIN_PROTOCOL_SCHEME"] as! String }
    var googleLoginProtocolScheme : String { return config["GOOGLE_LOGIN_PROTOCOL_SCHEME"] as! String }
    var googleMapsApiKey : String { return config["GOOGLE_MAPS_API_KEY"] as! String }
}


