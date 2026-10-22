package com.smallerbytes.defuseprotocol.offline

import android.content.Context
import fi.iki.elonen.NanoHTTPD
import java.io.InputStream
import java.net.URLConnection

/**
 * Serves APK assets/www over http://127.0.0.1 only (secure context for WebXR).
 */
class LocalWebServer(private val context: Context, port: Int) : NanoHTTPD("127.0.0.1", port) {
    override fun serve(session: IHTTPSession): Response {
        val method = session.method
        if (method != Method.GET && method != Method.HEAD) {
            return newFixedLengthResponse(
                Response.Status.METHOD_NOT_ALLOWED,
                MIME_PLAINTEXT,
                "Method not allowed"
            )
        }

        var uri = session.uri.substringBefore('?')
        if (uri == "/" || uri.isEmpty()) uri = "/index.html"
        if (uri.startsWith("/")) uri = uri.substring(1)

        // Reject path traversal and absolute escapes.
        if (uri.contains("..") || uri.startsWith("/") || uri.contains('\\')) {
            return newFixedLengthResponse(Response.Status.FORBIDDEN, MIME_PLAINTEXT, "Forbidden")
        }

        val assetPath = "www/$uri"
        val mimeType = mimeFor(uri)
        return try {
            if (method == Method.HEAD) {
                context.assets.open(assetPath).use { /* exists */ }
                newFixedLengthResponse(Response.Status.OK, mimeType, "")
            } else {
                val inputStream: InputStream = context.assets.open(assetPath)
                newChunkedResponse(Response.Status.OK, mimeType, inputStream)
            }
        } catch (_: Exception) {
            newFixedLengthResponse(Response.Status.NOT_FOUND, MIME_PLAINTEXT, "File not found")
        }
    }

    private fun mimeFor(uri: String): String {
        return when {
            uri.endsWith(".html") -> "text/html"
            uri.endsWith(".js") || uri.endsWith(".mjs") -> "application/javascript"
            uri.endsWith(".css") -> "text/css"
            uri.endsWith(".json") || uri.endsWith(".webmanifest") -> "application/json"
            uri.endsWith(".png") -> "image/png"
            uri.endsWith(".jpg") || uri.endsWith(".jpeg") -> "image/jpeg"
            uri.endsWith(".svg") -> "image/svg+xml"
            uri.endsWith(".webp") -> "image/webp"
            uri.endsWith(".mp3") -> "audio/mpeg"
            uri.endsWith(".wav") -> "audio/wav"
            uri.endsWith(".ogg") -> "audio/ogg"
            uri.endsWith(".glb") -> "model/gltf-binary"
            uri.endsWith(".gltf") -> "model/gltf+json"
            uri.endsWith(".wasm") -> "application/wasm"
            else -> URLConnection.guessContentTypeFromName(uri) ?: "application/octet-stream"
        }
    }
}
