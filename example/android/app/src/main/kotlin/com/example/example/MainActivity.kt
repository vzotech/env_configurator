package com.example.example


import EnvConfig
import android.util.Log
import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {



    override fun onStart() {
        super.onStart()

        val config = EnvConfig(this)
        Log.d("facebookAppId", config.facebookAppId)
        Log.d("fbLoginProtocolScheme", config.fbLoginProtocolScheme)
        Log.d("googleMapsApiKey", config.googleMapsApiKey)
    }
}
