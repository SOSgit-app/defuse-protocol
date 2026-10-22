package com.smallerbytes.defuseprotocol.offline

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.appcompat.app.AppCompatActivity

/**
 * Starts the localhost server, then opens the embedded game in Quest Browser.
 * Do NOT finish() this activity — killing it can tear down the server.
 */
class MainActivity : AppCompatActivity() {
    private val handler = Handler(Looper.getMainLooper())
    private var attempts = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val serviceIntent = Intent(this, ServerService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(serviceIntent)
        } else {
            startService(serviceIntent)
        }

        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(48, 48, 48, 48)
        }

        val status = TextView(this).apply {
            text =
                "Defuse Protocol\n\nLocal game server\nhttp://127.0.0.1:${ServerService.PORT}/\n\nOpening Quest Browser…"
            gravity = Gravity.CENTER
            textSize = 22f
            setPadding(0, 0, 0, 32)
        }

        val button = Button(this).apply {
            text = "Open game in Quest Browser"
            setOnClickListener { openQuestBrowser() }
        }

        layout.addView(status)
        layout.addView(button)
        setContentView(layout)

        waitForServerThenOpen()
    }

    private fun waitForServerThenOpen() {
        attempts++
        if (ServerService.isListening || attempts > 40) {
            openQuestBrowser()
            return
        }
        handler.postDelayed({ waitForServerThenOpen() }, 100)
    }

    private fun openQuestBrowser() {
        val url = "http://127.0.0.1:${ServerService.PORT}/"
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
            setPackage("com.oculus.browser")
            addCategory(Intent.CATEGORY_BROWSABLE)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        try {
            startActivity(intent)
        } catch (e: Exception) {
            // Fallback if Quest Browser package resolve fails on this OS build.
            try {
                startActivity(
                    Intent(Intent.ACTION_VIEW, Uri.parse(url)).apply {
                        addCategory(Intent.CATEGORY_BROWSABLE)
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    }
                )
            } catch (e2: Exception) {
                e2.printStackTrace()
            }
        }
    }
}
