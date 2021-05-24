// This code was generated by a tool
// Changes to this file may cause incorrect behavior and will be lost if the code is regenerated

import android.content.res.Resources
import com.example.example.R

abstract class EnvConfig {
    abstract val facebookAppId: String
    abstract val fbLoginProtocolScheme: String
    abstract val googleLoginProtocolScheme: String
    abstract val googleMapsApiKey: String
    abstract val someInt: Int
    abstract val someDecimalNumber: Float
}


class EnvConfigResources : EnvConfig() {
    private val resources: Resources = Resources.getSystem()

    override val facebookAppId: String get() = resources.getString(R.string.facebook_app_id)
    override val fbLoginProtocolScheme: String get() = resources.getString(R.string.fb_login_protocol_scheme)
    override val googleLoginProtocolScheme: String get() = resources.getString(R.string.google_login_protocol_scheme)
    override val googleMapsApiKey: String get() = resources.getString(R.string.google_maps_api_key)
    override val someInt: Int get() = resources.getInteger(R.integer.some_int)
    override val someDecimalNumber: Float get() = resources.getFraction(R.fraction.some_decimal_number, 1, 1)
}


