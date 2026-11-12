package com.mrhrafi3.sonora

import android.content.ContentUris
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : AudioServiceActivity() {
    private val channelName = "com.mrhrafi3.sonora/mediastore"
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSdkInt" -> result.success(Build.VERSION.SDK_INT)
                "queryAudioTracks" -> {
                    executor.execute {
                        try {
                            val tracks = queryAudioTracks()
                            mainHandler.post { result.success(tracks) }
                        } catch (e: Exception) {
                            mainHandler.post {
                                result.error("MEDIASTORE_ERROR", e.localizedMessage, null)
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        executor.shutdown()
        super.onDestroy()
    }

    private fun queryAudioTracks(): List<Map<String, Any?>> {
        val trackList = mutableListOf<Map<String, Any?>>()
        val contentResolver = applicationContext.contentResolver

        val collection: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL)
        } else {
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        }

        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.DISPLAY_NAME,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.DATA,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.DATE_MODIFIED,
            MediaStore.Audio.Media.MIME_TYPE,
            MediaStore.Audio.Media.YEAR,
            MediaStore.Audio.Media.TRACK,
            MediaStore.Audio.Media.ALBUM_ID
        )

        // Select music tracks >= 5s (to skip UI/ringtones), excluding ringtones,
        // notifications, and alarms, while allowing raw .aac streams whose duration
        // MediaStore may report as 0.
        val selection =
            "${MediaStore.Audio.Media.IS_MUSIC} != 0 AND " +
                "${MediaStore.Audio.Media.IS_RINGTONE} == 0 AND " +
                "${MediaStore.Audio.Media.IS_NOTIFICATION} == 0 AND " +
                "${MediaStore.Audio.Media.IS_ALARM} == 0 AND (" +
                "${MediaStore.Audio.Media.DURATION} >= 5000 OR " +
                "${MediaStore.Audio.Media.DISPLAY_NAME} LIKE '%.aac' OR " +
                "${MediaStore.Audio.Media.DATA} LIKE '%.aac')"
        val sortOrder = "${MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC"

        contentResolver.query(collection, projection, selection, null, sortOrder)?.use { cursor ->
            val idCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val titleCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val displayNameCol = cursor.getColumnIndex(MediaStore.Audio.Media.DISPLAY_NAME)
            val artistCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val albumCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
            val durationCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
            val dataCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
            val sizeCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)
            val dateModCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_MODIFIED)
            val mimeCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.MIME_TYPE)
            val yearCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.YEAR)
            val trackCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TRACK)
            val albumIdCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)

            while (cursor.moveToNext()) {
                val data = cursor.getString(dataCol) ?: ""
                if (isNonMusicPath(data)) {
                    continue
                }
                val id = cursor.getLong(idCol)
                val contentUri = ContentUris.withAppendedId(collection, id).toString()
                val displayName = if (displayNameCol >= 0) cursor.getString(displayNameCol) ?: "" else ""
                val title = cursor.getString(titleCol) ?: ""
                val artist = cursor.getString(artistCol)
                val album = cursor.getString(albumCol)
                val duration = cursor.getLong(durationCol)
                val size = cursor.getLong(sizeCol)
                val dateModified = cursor.getLong(dateModCol)
                val mimeType = cursor.getString(mimeCol)
                val year = cursor.getInt(yearCol)
                val trackNumber = cursor.getInt(trackCol)
                val albumId = cursor.getLong(albumIdCol)

                val trackMap = mapOf(
                    "id" to id.toString(),
                    "contentUri" to contentUri,
                    "filePath" to data,
                    "displayName" to displayName,
                    "title" to title,
                    "artist" to artist,
                    "album" to album,
                    "duration" to duration,
                    "size" to size,
                    "dateModified" to dateModified,
                    "mimeType" to mimeType,
                    "year" to year,
                    "trackNumber" to trackNumber,
                    "albumId" to albumId.toString()
                )
                trackList.add(trackMap)
            }
        }

        return trackList
    }

    private fun isNonMusicPath(path: String): Boolean {
        if (path.isEmpty()) return false
        val lower = path.lowercase().replace('\\', '/')
        return lower.contains("whatsapp") ||
                lower.contains("telegram") ||
                lower.contains("callrecordings") ||
                lower.contains("call recordings") ||
                lower.contains("call_recordings") ||
                lower.contains("voice recorder") ||
                lower.contains("voicerecorder") ||
                lower.contains("soundrecorder") ||
                lower.contains("voice notes") ||
                lower.contains("voicenotes") ||
                lower.contains("/calls/") ||
                lower.contains("/recordings/call") ||
                lower.contains("/ringtones/") ||
                lower.contains("/notifications/") ||
                lower.contains("/alarms/") ||
                lower.contains("/ui/") ||
                lower.contains("/.nomedia") ||
                lower.contains("/.")
    }
}
